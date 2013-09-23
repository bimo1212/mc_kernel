!=========================
 module global_parameters
!=========================
!
! This determines the precision for the memory-/CPU-intensive time loop. 
! Set the parameter realkind to either 
!   4: single precision (half memory compared to 8, faster on many systems)
!   8: double precision (more expensive (double memory), but more precise.
! The mesher is intrinsically double precision, as are all precomputed, mesh 
! related variables. This distinction is only relevant for the global 
! arrays used in the time evolution.

implicit  none
public

!@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

 integer, parameter          :: realkind = 4
!  integer, parameter          :: realkind = 8 

! Do not change these unless problems with any of the accuracy tests arise.
! As floating point rounding is system-dependent, there might be different 
! numbers for different systems, but the below values seem generally reasonable. 
  real(kind=4), parameter     :: smallval = 1e-6
  real(kind=8), parameter     :: smallval_dble = 1e-11

! Do not change these.
  real(kind=realkind), parameter :: zero =0d0,half=5d-1,third=1d0/3d0
  real(kind=realkind), parameter :: quart=25d-2,one=1d0,sixth=1d0/6d0
  real(kind=realkind), parameter :: two = 2d0,three=3d0,four=4d0,five=5.d0
  real(kind=realkind), parameter :: fifth = 2.d-1
  real(kind=realkind), parameter :: pi = 3.1415926535898D0
  real(kind=realkind), parameter :: epsi = 1d-30

!@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

!============================= 
 end module global_parameters
!=============================
