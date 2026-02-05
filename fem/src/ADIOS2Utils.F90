!/*****************************************************************************/
! *
! *  Elmer, A Finite Element Software for Multiphysical Problems
! *
! *  Copyright 1st April 1995 - , CSC - IT Center for Science Ltd., Finland
! * 
! *  This library is free software; you can redistribute it and/or
! *  modify it under the terms of the GNU Lesser General Public
! *  License as published by the Free Software Foundation; either
! *  version 2.1 of the License, or (at your option) any later version.
! *
! *  This library is distributed in the hope that it will be useful,
! *  but WITHOUT ANY WARRANTY; without even the implied warranty of
! *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
! *  Lesser General Public License for more details.
! * 
! *  You should have received a copy of the GNU Lesser General Public
! *  License along with this library (in file ../LGPL-2.1); if not, write 
! *  to the Free Software Foundation, Inc., 51 Franklin Street, 
! *  Fifth Floor, Boston, MA  02110-1301  USA
! *
! *****************************************************************************/
!
!/******************************************************************************
! *
! *  Authors: Juhani Kataja
! *  Email:   juhani.kataja@csc.fi
! *  Web:     http://www.csc.fi/elmer
! *  Address: CSC - IT Center for Science Ltd.
! *           Keilaranta 14
! *           02101 Espoo, Finland
! *
! *  Original Date: 08 Jun 1997
! *
! *****************************************************************************/

MODULE ADIOS2Utils
USE DefUtils
USE ADIOS2
IMPLICIT NONE

INTEGER, PARAMETER :: ADIOS2_ARRAY_GLOBAL = 1
INTEGER, PARAMETER :: ADIOS2_ARRAY_LOCAL = 2

! TODO: add global array support
TYPE :: AdiosWriter_t
  TYPE(adios2_adios), PRIVATE :: adios
  TYPE(adios2_io), PRIVATE :: io
  TYPE(adios2_engine), PRIVATE :: engine
  INTEGER(kind=4) :: array_kind
  LOGICAL, PRIVATE :: Finalized
  CONTAINS

  PROCEDURE, PUBLIC :: init => init_adios_t
  PROCEDURE, PUBLIC :: finalize => finalize_adios_t

  PROCEDURE, PRIVATE :: writer_real_t, writer_integer_t, writer_real_t_2
  PROCEDURE, PRIVATE :: get_adios_shape_1!, get_adios_shape_2

  GENERIC, PUBLIC :: write_data => writer_integer_t, writer_real_t, writer_real_t_2
  GENERIC :: get_shape => get_adios_shape_1!, get_adios_shape_2
  FINAL :: finalize_sub
END TYPE AdiosWriter_t

PRIVATE:: get_adios_shape

CONTAINS

! TODO: Fortran allows to expand this to n dimensions
SUBROUTINE get_adios_shape_1(this, array_dims, shape_dims, start_dims, count_dims)
  IMPLICIT NONE
  CLASS(AdiosWriter_t) :: this
  INTEGER(kind=4), dimension(1), intent(in) :: array_dims
  INTEGER(KIND=8), dimension(1), intent(out) :: shape_dims, start_dims, count_dims
  integer(kind=4), allocatable :: sum_dims(:)
  integer :: ierr

  IF (this % array_kind .eq. ADIOS2_ARRAY_LOCAL) THEN
    shape_dims(1) = array_dims(1)
    start_dims(1) = 0
    count_dims(1) = array_dims(1)
  ELSEIF(this%array_kind .eq. ADIOS2_ARRAY_GLOBAL) THEN
    allocate(sum_dims(size(array_dims,1)))
    sum_dims(:) = 0
    CALL MPI_AllReduce(array_dims, sum_dims, size(array_dims, 1), MPI_INTEGER, MPI_SUM, parenv % activecomm, ierr)
    shape_dims(1) = sum_dims(1)
    sum_dims(:) = 0
    print *, 'rank, shape_dims: ', parenv%mype, shape_dims
    call mpi_exscan(array_dims, sum_dims, 1, MPI_INTEGER, MPI_SUM, parenv % activecomm, ierr)
    start_dims(1) = sum_dims(1)
    print *, 'rank, start_dims: ', parenv%mype, start_dims
    count_dims(1) = array_dims(1)
  ELSE
    CALL Fatal('AdiosWriter_t', 'Unknown array_kind')
  END IF

END SUBROUTINE

SUBROUTINE get_adios_shape(n, shape_dims, start_dims, count_dims)
  IMPLICIT NONE
  INTEGER(KIND=8), dimension(1), intent(out) :: shape_dims, start_dims, count_dims
  INTEGER, intent(in) :: n
  shape_dims(1) = n
  start_dims(1) = 0
  count_dims(1) = n
END SUBROUTINE get_adios_shape

FUNCTION init_adios_t(this, fname, array_kind, mode) result(ierr)
  IMPLICIT NONE
  CLASS(AdiosWriter_t) :: this
  INTEGER :: ierr
  CHARACTER(*), intent(in) :: fname
  INTEGER, OPTIONAL :: mode
  INTEGER, OPTIONAL :: array_kind
  INTEGER :: mode_, array_kind_

  IF (present(mode)) THEN
    mode_ = mode
  else
    mode_ = adios2_mode_write
  END IF

  if (present(array_kind)) then
    this % array_kind = array_kind
  else
    this % array_kind = ADIOS2_ARRAY_GLOBAL
  end if

  CALL adios2_init(this % adios, parenv % activecomm, ierr)
  CALL adios2_declare_io(this % io, this % adios, "ioWriter", ierr)
  CALL adios2_open(this % engine, this % io, fname, mode_, ierr)
  this % finalized = .false.

END FUNCTION init_adios_t

FUNCTION finalize_adios_t(this) result(ierr)
  IMPLICIT NONE
  CLASS(AdiosWriter_t) :: this
  INTEGER :: ierr
  IF (.NOT. this % finalized) THEN
    CALL adios2_close(this%engine, ierr)
    CALL adios2_finalize(this%adios, ierr)
  END IF
  this % finalized = .true.
END FUNCTION finalize_adios_t

SUBROUTINE finalize_sub(this) 
  IMPLICIT NONE
  TYPE(AdiosWriter_t) :: this
  INTEGER :: ierr
  ierr = this%finalize()
END SUBROUTINE finalize_sub

SUBROUTINE writer_integer_t(this, varname, x)

  IMPLICIT NONE

  CLASS(AdiosWriter_t) :: this
  CHARACTER(*), intent(in) :: varname
  INTEGER(KIND=4), intent(in), dimension(:) :: x

  INTEGER(KIND=8), dimension(1) :: shape_dims, start_dims, count_dims
  INTEGER :: ierr
  CHARACTER(512) :: adios_varname ! TODO: declare parameter max_adios_varname or use automatic allocation here
  TYPE(adios2_variable) :: var

  if (this % array_kind .eq. ADIOS2_ARRAY_LOCAL) THEN
    adios_varname = "part_" // i2s(ParEnv % MyPE) // "/" // trim(varname)
  else
    adios_varname = trim(varname)
  end if

  CALL this % get_adios_shape_1(shape(x), shape_dims, start_dims, count_dims)

  CALL adios2_define_variable(var, this%io, adios_varname, adios2_type_integer4, 1, &
    shape_dims, start_dims, count_dims, adios2_constant_dims, ierr)
  CALL adios2_put(this%engine, var, x, ierr)

END SUBROUTINE writer_integer_t

SUBROUTINE writer_real_t_2(this, varname, x)

  IMPLICIT NONE

  CLASS(AdiosWriter_t) :: this
  CHARACTER(*), intent(in) :: varname
  REAL(KIND=dp), intent(in), dimension(:,:) :: x

  INTEGER(KIND=8), dimension(2) :: shape_dims, start_dims, count_dims
  INTEGER :: ierr
  CHARACTER(512) :: adios_varname
  TYPE(adios2_variable) :: var

  adios_varname = "part_" // i2s(ParEnv % MyPE) // "/" // trim(varname)

  shape_dims(1) = size(x,1)
  shape_dims(2) = size(x,2)
  start_dims(1) = 0
  start_dims(2) = 0
  count_dims(1) = shape_dims(1)
  count_dims(2) = shape_dims(2)

  CALL adios2_define_variable(var, this%io, adios_varname, adios2_type_double_precision, 2, &
    shape_dims, start_dims, count_dims, &
    adios2_constant_dims, ierr)
  CALL adios2_put(this%engine, var, x, ierr)

END SUBROUTINE writer_real_t_2

SUBROUTINE writer_real_t(this, varname, x)

  IMPLICIT NONE

  CLASS(AdiosWriter_t) :: this
  CHARACTER(*), intent(in) :: varname
  REAL(KIND=dp), intent(in), dimension(:) :: x

  INTEGER(KIND=8), dimension(1) :: shape_dims, start_dims, count_dims
  INTEGER :: ierr
  CHARACTER(512) :: adios_varname
  TYPE(adios2_variable) :: var

  adios_varname = "part_" // i2s(ParEnv % MyPE) // "/" // trim(varname)

  CALL get_adios_shape(size(x,1), shape_dims, start_dims, count_dims)
  CALL adios2_define_variable(var, this%io, adios_varname, adios2_type_double_precision, 1, &
    shape_dims, start_dims, count_dims, adios2_constant_dims, ierr)
  CALL adios2_put(this%engine, var, x, ierr)

END SUBROUTINE writer_real_t

END MODULE
