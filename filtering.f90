!=========================================================================================
module filtering
   
   use global_parameters
   use simple_routines,  only           : mult2d_1d, mult3d_1d
   use commpi,           only           : pabort
   
   implicit none

   type filter_type
       character(len=32)               :: name
       complex(kind=dp), allocatable   :: transferfunction(:)
       integer                         :: nfreq                !< Number of frequencies
       real(kind=dp), allocatable      :: f(:)
       logical                         :: initialized = .false.
       logical                         :: stf_added = .false.
       character(len=32)               :: filterclass
       real(kind=dp)                   :: frequencies(4)

       contains
       procedure, pass   :: create
       procedure, pass   :: add_stfs
       procedure, pass   :: deleteme
       procedure, pass   :: apply_1d
       procedure, pass   :: apply_2d
       procedure, pass   :: apply_3d
       procedure, pass   :: isinitialized
       procedure, pass   :: get_transferfunction
   end type

   type timeshift_type
       complex(kind=dp), allocatable  :: shift_fd(:) !< Array with complex multiplicators 
                                                     !! to apply the timeshift
       logical                        :: isinitialized = .false.
       contains
       procedure, pass   :: init_ts
       procedure, pass   :: timeshift_1d
       procedure, pass   :: timeshift_md
       procedure, pass   :: freeme
       generic           :: apply => timeshift_1d, timeshift_md
   end type

contains

!-----------------------------------------------------------------------------------------
!> Create a filter object with the specified parameters
subroutine create(this, name, dfreq, nfreq, filterclass, frequencies)

    class(filter_type)              :: this
    integer, intent(in)             :: nfreq
    real(kind=dp), intent(in)       :: dfreq, frequencies(4)
    integer                         :: ifreq
    character(len=32), intent(in)   :: name
    character(len=32), intent(in)   :: filterclass

    character(len=32)               :: fmtstring
    character(len=64)               :: fnam

    fmtstring = '("Class: ", A, ", freq: ", 4(F8.4))'

    if (this%initialized) then
       write(*,*) 'ERROR: This filter is already initialized as'
       write(*, fmtstring) trim(this%filterclass), this%frequencies
       write(*,*) 'delete it first before using'
       call pabort
    end if
    allocate(this%transferfunction(nfreq))
    allocate(this%f(nfreq))

    this%name              = name
    this%transferfunction  = 0.0
    this%nfreq             = nfreq
    this%filterclass       = filterclass
    this%frequencies       = frequencies

    do ifreq = 1, nfreq
       this%f(ifreq) = dfreq * (ifreq-1)
    end do

    select case(trim(filterclass))
    case('Gabor')
       this%transferfunction = loggabor(this%f, frequencies(1), frequencies(2))

    case('Butterw_LP_O2')
       this%transferfunction = butterworth_lowpass(this%f, frequencies(1), 2)
    case('Butterw_HP_O2')
       this%transferfunction = butterworth_highpass(this%f, frequencies(1), 2)
    case('Butterw_BP_O2')
       this%transferfunction = butterworth_highpass(this%f, frequencies(1), 2) &
                             * butterworth_lowpass(this%f, frequencies(2), 2)
    case('Butterw_LP_O4')
       this%transferfunction = butterworth_lowpass(this%f, frequencies(1), 4)
    case('Butterw_HP_O4')
       this%transferfunction = butterworth_highpass(this%f, frequencies(1), 4)
    case('Butterw_BP_O4')
       this%transferfunction = butterworth_highpass(this%f, frequencies(1), 4) &
                             * butterworth_lowpass(this%f, frequencies(2), 4)
    case('Butterw_LP_O6')
       this%transferfunction = butterworth_lowpass(this%f, frequencies(1), 6)
    case('Butterw_HP_O6')
       this%transferfunction = butterworth_highpass(this%f, frequencies(1), 6)
    case('Butterw_BP_O6')
       this%transferfunction = butterworth_highpass(this%f, frequencies(1), 6) &
                             * butterworth_lowpass(this%f, frequencies(2), 6)
    case('Butterw_LP_O8')
       this%transferfunction = butterworth_lowpass(this%f, frequencies(1), 8)
    case('Butterw_HP_O8')
       this%transferfunction = butterworth_highpass(this%f, frequencies(1), 8)
    case('Butterw_BP_O8')
       this%transferfunction = butterworth_highpass(this%f, frequencies(1), 8) &
                             * butterworth_lowpass(this%f, frequencies(2), 8)

    case('Butterw_LP_O2_ZP')
       this%transferfunction = butterworth_lowpass(this%f, frequencies(1), 2)
       this%transferfunction = this%transferfunction * conjg(this%transferfunction)
    case('Butterw_HP_O2_ZP')
       this%transferfunction = butterworth_highpass(this%f, frequencies(1), 2)
       this%transferfunction = this%transferfunction * conjg(this%transferfunction)
    case('Butterw_BP_O2_ZP')
       this%transferfunction = butterworth_highpass(this%f, frequencies(1), 2) &
                             * butterworth_lowpass(this%f, frequencies(2), 2)
       this%transferfunction = this%transferfunction * conjg(this%transferfunction)
    case('Butterw_LP_O4_ZP')
       this%transferfunction = butterworth_lowpass(this%f, frequencies(1), 4)
       this%transferfunction = this%transferfunction * conjg(this%transferfunction)
    case('Butterw_HP_O4_ZP')
       this%transferfunction = butterworth_highpass(this%f, frequencies(1), 4)
       this%transferfunction = this%transferfunction * conjg(this%transferfunction)
    case('Butterw_BP_O4_ZP')
       this%transferfunction = butterworth_highpass(this%f, frequencies(1), 4) &
                             * butterworth_lowpass(this%f, frequencies(2), 4)
       this%transferfunction = this%transferfunction * conjg(this%transferfunction)
    case('Butterw_LP_O6_ZP')
       this%transferfunction = butterworth_lowpass(this%f, frequencies(1), 6)
       this%transferfunction = this%transferfunction * conjg(this%transferfunction)
    case('Butterw_HP_O6_ZP')
       this%transferfunction = butterworth_highpass(this%f, frequencies(1), 6)
       this%transferfunction = this%transferfunction * conjg(this%transferfunction)
    case('Butterw_BP_O6_ZP')
       this%transferfunction = butterworth_highpass(this%f, frequencies(1), 6) &
                             * butterworth_lowpass(this%f, frequencies(2), 6)
       this%transferfunction = this%transferfunction * conjg(this%transferfunction)
    case('Butterw_LP_O8_ZP')
       this%transferfunction = butterworth_lowpass(this%f, frequencies(1), 8)
       this%transferfunction = this%transferfunction * conjg(this%transferfunction)
    case('Butterw_HP_O8_ZP')
       this%transferfunction = butterworth_highpass(this%f, frequencies(1), 8)
       this%transferfunction = this%transferfunction * conjg(this%transferfunction)
    case('Butterw_BP_O8_ZP')
       this%transferfunction = butterworth_highpass(this%f, frequencies(1), 8) &
                             * butterworth_lowpass(this%f, frequencies(2), 8)
       this%transferfunction = this%transferfunction * conjg(this%transferfunction)
    case default
       print *, 'ERROR: Unknown filter type: ', trim(filterclass)
       call pabort
    end select

    if (firstslave) then
20     format('filterresponse_', A, 2('_', F0.6))
       write(fnam,20) trim(filterclass), frequencies(1:2)

       open(10, file=trim(fnam), action='write')
       do ifreq = 1, nfreq
          write(10,*), this%f(ifreq), real(this%transferfunction(ifreq)), &
                                      imag(this%transferfunction(ifreq))
       end do
       close(10)
    end if   

    this%initialized = .true.
    this%stf_added = .false.

end subroutine create
!-----------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------
!> Devides the transferfunction of the filter with the complex spectra of 
!! the Source time function of the forward SEM simulation, to cancel its effect.
!! The filter uses only the forward STF, since fwd and bwd simulation are checked to
!! have the same STF in readfields.f90
!! We could get around this by having separate filters for the forward and the backward 
!! field. 
!! If we had nothing else to do.
subroutine add_stfs(this, stf_fwd, amplitude_fwd, stf_dt)
    use fft,                     only: rfft_type, taperandzeropad
    use simple_routines,         only: firstderiv
    class(filter_type)              :: this
    real(kind=dp)   , intent(in)    :: stf_fwd(:)
    real(kind=dp)   , intent(in)    :: amplitude_fwd, stf_dt

    ! The FFT routines need 2D arrays. Second dimension will be size 1
    real(kind=dp)   , allocatable   :: stf(:,:), stf_td(:,:), t(:)
    complex(kind=dp), allocatable   :: stf_fd(:,:), lowpass(:)

    type(rfft_type)                 :: fft_stf
    character(len=64)               :: fnam
    integer                         :: ifreq
    real(kind=dp)                   :: waterlevel

    if (.not.this%initialized) then
       write(*,*) 'ERROR: Filter is not initialized yet'
       call pabort
    end if

    if (this%stf_added) then
       write(*,*) 'ERROR: STF has already been added to filter ', trim(this%name)
       call pabort
    end if

    call fft_stf%init(ntimes_in = size(stf_fwd), &
                      ndim      = 1,             &
                      ntraces   = 1,             &
                      dt        = stf_dt )


    allocate(stf(size(stf_fwd), 1))
    allocate(stf_fd(this%nfreq, 1))
    allocate(stf_td(fft_stf%get_ntimes(), 1))
    t = fft_stf%get_t()

    stf(:,1) = stf_fwd 

    call fft_stf%rfft(taperandzeropad(stf, fft_stf%get_ntimes(), ntaper = 5), stf_fd)

    if (firstslave) then
18     format('stf_spectrum_', A, 2('_', F0.3))
19     format(5(E16.8))
       write(fnam,18) trim(this%filterclass), this%frequencies(1:2)

       open(10, file=trim(fnam), action='write')
       do ifreq = 1, this%nfreq
           write(10,19), this%f(ifreq), real(stf_fd(ifreq,1)), imag(stf_fd(ifreq,1))
       end do
       close(10)
    end if

    ! Calculate first derivatice of the STF
    stf_fd(:,1) = stf_fd(:,1) * this%f * (2.0d0 * pi * cmplx(0.0d0,1.0d0))


    ! Divide filter by spectrum of forward STF. It is established at initialization
    ! that forward and backward STF are identical.
    this%transferfunction = this%transferfunction / stf_fd(:,1)

    this%transferfunction = this%transferfunction * amplitude_fwd 

    ! Apply high order butterworth filter to delete frequencies above mesh frequency
    lowpass = butterworth_lowpass(this%f, this%f(this%nfreq/4), 16)
    lowpass = lowpass * conjg(lowpass)
  
    this%transferfunction = this%transferfunction * lowpass

    ! Replace NaNs with zero
    where(abs(this%transferfunction).ne.abs(this%transferfunction)) 
      this%transferfunction = cmplx(0d0, 0d0)
    end where

    call fft_stf%irfft(stf_fd, stf_td)

    call fft_stf%freeme()

    if (firstslave) then
20     format('filterresponse_stf_', A, 2('_', F0.3))
       write(fnam,20) trim(this%filterclass), this%frequencies(1:2)
       open(10, file=trim(fnam), action='write')
       do ifreq = 1, this%nfreq
          write(10,*), this%f(ifreq), real(this%transferfunction(ifreq)), &
                                      imag(this%transferfunction(ifreq))
       end do
       close(10)
       
21     format('stf_spectrum_deriv_', A, 2('_', F0.3))
22     format(5(E16.8))
       write(fnam,21) trim(this%filterclass), this%frequencies(1:2)

       open(10, file=trim(fnam), action='write')
       do ifreq = 1, this%nfreq
           write(10,22), this%f(ifreq), real(stf_fd(ifreq,1)), imag(stf_fd(ifreq,1))
       end do
       close(10)
       
23     format('stf_', A, 2('_', F0.3))
24     format(3(E16.8))
       write(fnam,23) trim(this%filterclass), this%frequencies(1:2)

       open(10, file=trim(fnam), action='write')
       do ifreq = 1, size(stf_fwd)
          write(10,24), t(ifreq), stf_fwd(ifreq)
       end do
       close(10)
       
25     format('stf_deriv_', A, 2('_', F0.3))
26     format(3(E16.8))
       write(fnam,25) trim(this%filterclass), this%frequencies(1:2)

       open(10, file=trim(fnam), action='write')
       do ifreq = 1, size(stf_fwd)
          write(10,26), t(ifreq), stf_td(ifreq,1)
       end do
       close(10)
    end if   

    if (maxloc(abs(this%transferfunction),1) > 0.5*this%nfreq) then
       if (firstslave) then
         print *, 'ERROR: Filter ', trim(this%name), ' is not vanishing fast enough for '
         print *, 'high frequencies.'
         print *, 'Numerical noise from frequencies above mesh limit will be propagated'
         print *, 'into the kernels. Check the files'
         print *, 'filterresponse*'
         print *, 'filterresponse_stf_*'
         print *, 'stf_spectrum_*'
         print *, 'Maximum frequency: ', this%f(maxloc(abs(this%transferfunction),1))
       end if
       stop
    end if

    this%stf_added = .true.

end subroutine add_stfs
!-----------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------
!> Delete this filter and free the memory
subroutine deleteme(this)

    class(filter_type)              :: this

    this%filterclass = ''
    deallocate(this%transferfunction)
    deallocate(this%f)
    this%initialized = .false.

end subroutine deleteme
!-----------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------
!> Apply this filter to one trace (in the frequency domain)
function apply_1d(this, freq_series)

   class(filter_type)               :: this
   complex(kind=dp), intent(in)     :: freq_series(:)
   complex(kind=dp)                 :: apply_1d(size(freq_series))

   if (.not.this%initialized) then
      write(*,*) 'ERROR: Filter is not initialized yet'
      call pabort(do_traceback=.false.)
   end if

   if (size(freq_series, 1).ne.this%nfreq) then
      write(*,*) 'ERROR: Filter length: ', this%nfreq, ', data length: ', &
                    size(freq_series, 1)
      call pabort(do_traceback=.false.)
   end if

   apply_1d = freq_series * this%transferfunction
end function apply_1d 
!-----------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------
!> Apply this filter to multiple traces (in the frequency domain)
function apply_2d(this, freq_series)

   class(filter_type)               :: this
   complex(kind=dp), intent(in)     :: freq_series(:,:)
   complex(kind=dp)                 :: apply_2d(size(freq_series,1), size(freq_series,2))
   integer                          :: itrace

   if (.not.this%initialized) then
      write(*,*) 'ERROR: Filter is not initialized yet'
      call pabort(do_traceback=.false.)
   end if

   if (size(freq_series, 1).ne.this%nfreq) then
      write(*,*) 'ERROR: Filter length: ', this%nfreq, ', data length: ', &
                    size(freq_series, 1)
      call pabort(do_traceback=.false.)
   end if
   
   do itrace = 1, (size(freq_series, 2))
      apply_2d(:,itrace) = freq_series(:,itrace) * this%transferfunction(:)
   end do

end function apply_2d
!-----------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------
!> Apply this filter to multiple dimensions and traces (in the frequency domain)
function apply_3d(this, freq_series)

   use simple_routines, only       :  mult3d_1d
   
   class(filter_type)              :: this
   complex(kind=dp), intent(in)    :: freq_series(:,:,:)
   complex(kind=dp)                :: apply_3d(size(freq_series,1), size(freq_series,2), &
                                               size(freq_series,3))

   if (.not.this%initialized) then
      write(*,*) 'ERROR: Filter is not initialized yet'
      call pabort(do_traceback=.false.)
   end if

   if (size(freq_series, 1).ne.this%nfreq) then
      write(*,*) 'ERROR: Filter length: ', this%nfreq, ', data length: ', &
                    size(freq_series, 1)
      call pabort
   end if

   apply_3d = mult3d_1d(freq_series, this%transferfunction)

end function apply_3d
!-----------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------
!> Returns the transfer function of this filter
function get_transferfunction(this)
    class(filter_type)           :: this
    real(kind=dp)                :: get_transferfunction(this%nfreq, 3)

    if (.not.this%initialized) then
       write(*,*) 'ERROR: Filter is not initialized yet'
       call pabort
    end if
    get_transferfunction(:,1) = this%f(:)
    get_transferfunction(:,2) = real(this%transferfunction(:))
    get_transferfunction(:,3) = imag(this%transferfunction(:))

end function
!-----------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------
function isinitialized(this)
   class(filter_type)            :: this
   logical                       :: isinitialized

   isinitialized = this%initialized
end function
!-----------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------
!> Init a timeshift object
subroutine init_ts(this, freq, dtshift)
   class(timeshift_type)            :: this
   real(kind=dp),    intent(in)     :: freq(:)     !< 1D array with the frequencies of 
                                                   !! the entries in field
                                                   !! Dimension: nfreq
   real(kind=dp),    intent(in)     :: dtshift     !< Time shift to apply (in seconds)

   if (verbose>1) &
      write(lu_out, *) 'Initializing timeshift object with ', dtshift, ' sec'
   allocate(this%shift_fd(size(freq,1)) )
   this%shift_fd = exp( 2*pi * cmplx(0., 1.) * freq(:) * dtshift)
   this%isinitialized = .true.


end subroutine
!-----------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------
!> Apply a timeshift of dtshift on the frequency domain traces in field
subroutine timeshift_md(this, field)
   class(timeshift_type)            :: this
   complex(kind=dp), intent(inout)  :: field(:,:,:) !< Frequency domain traces to apply 
                                                   !! time shift on. 
                                                   !! Dimension: nfreq x ndim x ntraces
   if (this%isinitialized) then
     field(:,:,:) = mult3d_1d(field, this%shift_fd)
   else
     write(*,*) 'Timeshift is not initialized yet!'
     call pabort()
   end if

end subroutine
!-----------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------
!> Apply a timeshift of dtshift on the frequency domain traces in field
subroutine timeshift_1d(this, field)
   class(timeshift_type)            :: this
   complex(kind=dp), intent(inout)  :: field(:,:)  !< Frequency domain traces to apply 
                                                   !! time shift on. 
                                                   !! Dimension: nfreq x ntraces
   if (this%isinitialized) then
     field(:,:) = mult2d_1d(field, this%shift_fd)
   else
     write(*,*) 'Timeshift is not initialized yet!'
     call pabort()
   end if

end subroutine
!-----------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------
!> Delete this timeshift object
subroutine freeme(this)
   class(timeshift_type)           :: this

   if (allocated(this%shift_fd)) deallocate(this%shift_fd)

end subroutine
!-----------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------!
!                 BLOCK WITH SEPARATE FILTER ROUTINES                         !
!-----------------------------------------------------------------------------!

!-----------------------------------------------------------------------------------------
function loggabor(f, p_c, sigma)             !< Log-Gabor filter as employed by K. Sigloch

    real(kind=dp), intent(in)   :: f(:)  !< Frequency array
    real(kind=dp), intent(in)   :: p_c   !< Center period of the filter
    real(kind=dp), intent(in)   :: sigma !< (fixed) ratio of sigma divided by p_c, where
                                         !! sigma is the standard deviation of the
                                         !! Gaussian that describes the log-Gabor filter
                                         !! in the *time* domain, and fc is the filter's
                                         !! center frequency.  Hence larger sigmaIfc means
                                         !! narrower bandwidth sigmaIfc = .5 means the
                                         !! one-sigma interval i equals one octave

    real(kind=dp)               :: loggabor(size(f))
    real(kind=dp)               :: f_c

    f_c = 1 / p_c
    loggabor = 0
    where (f>0.0d0) loggabor = exp( -(log(f/f_c))**2 / ( 2 * log(sigma)**2) )
    ! G(f,k) = exp( -(ln(f/f_k))^2 / (2*ln(sigmaIfc)^2)  )

end function loggabor
!-----------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------
function butterworth_lowpass(f, p_c, n)
    !http://en.wikipedia.org/wiki/Butterworth_filter

    real(kind=dp), intent(in)   :: f(:)  !< Frequency array
    real(kind=dp), intent(in)   :: p_c   !< cutoff period of the filter
    integer, intent(in)         :: n     !< order

    complex(kind=dp)            :: butterworth_lowpass(size(f))
    real(kind=dp)               :: omega_c
    complex(kind=dp)            :: s(1:n), j
    integer                     :: k

    omega_c = 2 * pi / p_c
    j = cmplx(0, 1)

    do k=1, n
        s(k) = omega_c * exp(j * (2 * k + n - 1) * pi / (2 * n))
    enddo

    butterworth_lowpass = 1

    do k=1, n
        butterworth_lowpass = butterworth_lowpass / ((2 * pi * j * f - s(k)) / omega_c)
    enddo

end function butterworth_lowpass
!-----------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------
function butterworth_highpass(f, p_c, n)
    !http://en.wikipedia.org/wiki/Butterworth_filter
    !http://en.wikipedia.org/wiki/Prototype_filter#Lowpass_to_highpass

    real(kind=dp), intent(in)   :: f(:)  !< Frequency array
    real(kind=dp), intent(in)   :: p_c   !< cutoff period of the filter
    integer, intent(in)         :: n     !< order

    complex(kind=dp)            :: butterworth_highpass(size(f))
    real(kind=dp)               :: omega_c
    complex(kind=dp)            :: s(1:n), j
    integer                     :: k

    omega_c = 2 * pi / p_c
    j = cmplx(0, 1)

    do k=1, n
        s(k) = omega_c * exp(j * (2 * k + n - 1) * pi / (2 * n))
    enddo

    butterworth_highpass = 1

    do k=1, n
        butterworth_highpass(2:) &
            = butterworth_highpass(2:) / (omega_c / (2 * pi * j * f(2:)) - s(k) / omega_c)
    enddo
    butterworth_highpass(1) = 0

end function butterworth_highpass
!-----------------------------------------------------------------------------------------

end module
!=========================================================================================
