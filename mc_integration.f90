module montecarlo
    
    use global_parameters
    use commpi, only                              : pabort
    implicit none

    type                                         :: integrated_type
        private
        integer                                  :: nfuncs
        real(kind=dp), dimension(:), allocatable :: fsum, f2sum
        real(kind=dp), dimension(:), allocatable :: integral
        real(kind=dp), dimension(:), allocatable :: allowed_variance
        real(kind=dp), dimension(:), allocatable :: allowed_relerror
        real(kind=dp), dimension(:), allocatable :: variance
        real(kind=dp)                            :: volume
        logical, dimension(:), allocatable       :: converged
        integer                                  :: nmodels
        logical                                  :: isinitialized = .false.
        
     contains
        procedure, pass                          :: check_montecarlo_integral
        procedure, pass                          :: initialize_montecarlo
        procedure, pass                          :: areallconverged
        procedure, pass                          :: countconverged
        procedure, pass                          :: getintegral
        procedure, pass                          :: getvariance
        procedure, pass                          :: isconverged
        procedure, pass                          :: freeme

    end type

    public                                       :: allallconverged
    public                                       :: allisconverged
contains

!-------------------------------------------------------------------------------
subroutine check_montecarlo_integral(this, func_values)
    class(integrated_type)                    :: this
    real(kind=dp), dimension(:,:), intent(in) :: func_values !(npoints, nfuncs)

    integer                                   :: npoints, ifuncs
    
    if (.not.this%isinitialized) then
       write(*,*) 'Initialize this MC type first'
       call pabort 
    end if

    if (size(func_values, 2).ne.this%nfuncs) then
      print *, 'Wrong number of functions in check_montecarlo_integral'
      print *, 'Type was initialized with: ', this%nfuncs
      print *, 'but func_values has size:  ', size(func_values, 2)
      call pabort()
    end if

    npoints = size(func_values, 1)
    this%nmodels = this%nmodels + npoints

    do ifuncs = 1, this%nfuncs
        if(this%converged(ifuncs)) cycle
        ! https://en.wikipedia.org/wiki/Monte_Carlo_Integration
        this%fsum(ifuncs)     = this%fsum(ifuncs)  + sum(func_values(:,ifuncs))
        this%f2sum(ifuncs)    = this%f2sum(ifuncs) + sum(func_values(:,ifuncs)**2)

        this%integral(ifuncs) = this%fsum(ifuncs) * &
                                this%volume / this%nmodels

        this%variance(ifuncs) = this%volume**2 / this%nmodels *    &
                                (  (this%f2sum(ifuncs) / this%nmodels)     &
                                 - (this%fsum(ifuncs)  / this%nmodels)**2  )

        if (this%integral(ifuncs).ne.this%integral(ifuncs)) then
           print *, 'Monte Carlo Integration:'
           print *, 'Integral of function ', ifuncs, ' is NaN'
           print *, 'int:   ', this%integral(ifuncs)
           print *, 'var:   ', this%variance(ifuncs)
           print *, 'fsum:  ', this%fsum(ifuncs)
           print *, 'f2sum: ', this%f2sum(ifuncs)
           print *, 'current value: ', func_values(:, ifuncs)
           call pabort
        end if
        if (this%variance(ifuncs).ne.this%variance(ifuncs)) then
           print *, 'Monte Carlo Integration:'
           print *, 'Variance of function ', ifuncs, ' is NaN'
           print *, 'int:   ', this%integral(ifuncs)
           print *, 'var:   ', this%variance(ifuncs)
           print *, 'fsum:  ', this%fsum(ifuncs)
           print *, 'f2sum: ', this%f2sum(ifuncs)
           print *, 'current value: ', func_values(:, ifuncs)
           call pabort
        end if
        ! Check absolute error
        if (this%variance(ifuncs) < this%allowed_variance(ifuncs)) then
           this%converged(ifuncs) = .true.
        ! Check relative error
        elseif (sqrt(this%variance(ifuncs)) < &
                this%allowed_relerror(ifuncs)*abs(this%integral(ifuncs))) then
           this%converged(ifuncs) = .true.
        end if

    end do

end subroutine check_montecarlo_integral
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
subroutine initialize_montecarlo(this, nfuncs, volume, allowed_error, allowed_relerror, int_over_volume)
    class(integrated_type), intent(inout) :: this 
    integer, intent(in)                   :: nfuncs
    real(kind=dp), intent(in)             :: volume
    real(kind=dp), intent(in)             :: allowed_error
    real(kind=dp), intent(in), optional   :: allowed_relerror
    logical, intent(in), optional         :: int_over_volume

    if(allocated(this%fsum)) deallocate(this%fsum)
    if(allocated(this%f2sum)) deallocate(this%f2sum)
    if(allocated(this%converged)) deallocate(this%converged)
    if(allocated(this%integral)) deallocate(this%integral)
    if(allocated(this%variance)) deallocate(this%variance)
    if(allocated(this%allowed_variance)) deallocate(this%allowed_variance)
    if(allocated(this%allowed_relerror)) deallocate(this%allowed_relerror)
    
    allocate(this%fsum(nfuncs))
    allocate(this%f2sum(nfuncs))
    allocate(this%converged(nfuncs))
    allocate(this%integral(nfuncs))
    allocate(this%variance(nfuncs))
    allocate(this%allowed_variance(nfuncs))
    allocate(this%allowed_relerror(nfuncs))

    this%volume           = volume
    this%nfuncs           = nfuncs
    this%fsum             = 0
    this%f2sum            = 0
    this%allowed_variance = allowed_error ** 2
    this%converged        = .false.
    this%nmodels          = 0

    if(present(allowed_relerror)) then
       this%allowed_relerror = allowed_relerror
    else
       this%allowed_relerror = 1d-100
    end if

    ! for plotting one may wish to skip volume integration
    if(present(int_over_volume)) then
       if (.not.int_over_volume) then
          this%volume = 1.d0
       end if
    end if


    this%isinitialized    = .true.

end subroutine initialize_montecarlo
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
subroutine freeme(this)
    class(integrated_type), intent(inout) :: this 

    deallocate(this%fsum)
    deallocate(this%f2sum)
    deallocate(this%converged)
    deallocate(this%integral)
    deallocate(this%variance)
    deallocate(this%allowed_variance)
    this%isinitialized = .false.
    
end subroutine
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
function getintegral(this)
    class(integrated_type)                :: this
    real(kind=dp), dimension(this%nfuncs) :: getintegral

    if (.not.this%isinitialized) then
       write(*,*) 'Initialize this MC type first'
       call pabort 
    end if
    getintegral = this%integral

end function
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
function getvariance(this)
    class(integrated_type)                :: this
    real(kind=dp), dimension(this%nfuncs) :: getvariance

    if (.not.this%isinitialized) then
       write(*,*) 'Initialize this MC type first'
       call pabort 
    end if
    getvariance = this%variance

end function
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
function countconverged(this, ikernels)
    class(integrated_type)        :: this
    integer                       :: countconverged
    integer, optional, intent(in) :: ikernels(:)

    if (.not.this%isinitialized) then
       write(*,*) 'Initialize this MC type first'
       call pabort 
    end if

    if (present(ikernels)) then
       countconverged = count(this%converged(ikernels))
    else 
       countconverged = count(this%converged)
    end if

end function
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
function areallconverged(this, ikernels)
    class(integrated_type)        :: this
    logical                       :: areallconverged
    integer, optional, intent(in) :: ikernels(:)

    if (.not.this%isinitialized) then
       write(*,*) 'Initialize this MC type first'
       call pabort 
    end if

    if (present(ikernels)) then
       areallconverged = all(this%converged(ikernels))
    else 
       areallconverged = all(this%converged)
    end if

end function
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
function isconverged(this, ifunc)
    class(integrated_type)                :: this
    integer                               :: ifunc
    logical                               :: isconverged

    if (.not.this%isinitialized) then
       write(*,*) 'Initialize this MC type first'
       call pabort 
    end if

    isconverged = this%converged(ifunc)

end function
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
function allallconverged(int_object, ikernels)
    type(integrated_type), intent(in)    :: int_object(:)
    logical                              :: allallconverged
    logical                              :: anynotconverged
    integer, optional, intent(in)        :: ikernels(:)
    integer                              :: ivertex, nvertices

    nvertices = size(int_object,1)
    anynotconverged = .false.

    do ivertex = 1, nvertices
        if (present(ikernels)) then
           anynotconverged = .not.(all(int_object(ivertex)%converged(ikernels))).or.anynotconverged
        else 
           anynotconverged = .not.(all(int_object(ivertex)%converged(:))).or.anynotconverged
        end if
    end do
    allallconverged = .not.anynotconverged

end function
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
function allisconverged(int_object, ikernel)
    type(integrated_type), intent(in)   :: int_object(:)
    logical                              :: allisconverged
    logical                              :: anynotconverged
    integer, optional, intent(in)        :: ikernel
    integer                              :: ivertex, nvertices

    nvertices = size(int_object)
    anynotconverged = .false.
    do ivertex = 1, nvertices
        anynotconverged = .not.(int_object(ivertex)%converged(ikernel)).or.anynotconverged
    end do
    allisconverged = .not.anynotconverged

end function
!-------------------------------------------------------------------------------
end module
