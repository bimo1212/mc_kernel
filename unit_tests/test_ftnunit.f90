!=========================================================================================
program test_ftnunit

  use ftnunit
  use test_montecarlo
  use test_fft
  use test_tetrahedra
  use test_inversion_mesh
  implicit none

  call runtests_init
  call runtests( test_all )
  call runtests_final

contains

!-----------------------------------------------------------------------------------------
subroutine test_all
  ! test_montecarlo
  write(6,'(/,a)') 'TEST MONTECARLO MODULE'
  call test(test_unit_hexagon, 'MC_unit_hexagon')
  call test(test_sphere_in_tetrahedron, 'MC sphere in tetrahedron')

  ! test_fft
  write(6,'(/,a)') 'TEST FFT MODULE'
  call test(test_fft_dirac, 'FFT_dirac')
  call test(test_fft_inverse, 'FFT_inverse')

  ! test_tetrahedra
  write(6,'(/,a)') 'TEST TETRAHEDRON MODULE'
  call test(test_generate_random_point, 'Random points in Tetrahedra')
  call test(test_rmat4_det, 'Matrix determinant')
  call test(test_tetra_volume_3d, 'Tetrahedron volume')

  ! test_inversion_mesh
  write(6,'(/,a)') 'TEST INVERSION MESH MODULE'
  call test(test_mesh_read, 'reading tetrahedral mesh')
  call test(test_mesh_dump, 'reading/dumping tetrahedral mesh')
  call test(test_mesh_data_dump, 'reading/dumping tetrahedral mesh with data')
  call test(test_valence, 'computation of valence')
end subroutine
!-----------------------------------------------------------------------------------------

end program
!=========================================================================================
