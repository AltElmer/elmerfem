MODULE ADIOS2Utils
USE DefUtils
USE ADIOS2
IMPLICIT NONE

TYPE :: AdiosWriter_t
  TYPE(adios2_adios), PRIVATE :: adios
  TYPE(adios2_io), PRIVATE :: io
  TYPE(adios2_engine), PRIVATE :: engine
  LOGICAL, PRIVATE :: Finalized
  CONTAINS

  PROCEDURE, PRIVATE :: writer_real_t, writer_integer_t
  PROCEDURE, PUBLIC :: init => init_adios_t
  PROCEDURE, PUBLIC :: finalize => finalize_adios_t
  GENERIC, PUBLIC :: write_data => writer_integer_t, writer_real_t
  FINAL :: finalize_sub
END TYPE AdiosWriter_t

PRIVATE:: get_adios_shape

CONTAINS

SUBROUTINE get_adios_shape(n, shape_dims, start_dims, count_dims)
  IMPLICIT NONE
  INTEGER(KIND=8), dimension(1), intent(out) :: shape_dims, start_dims, count_dims
  INTEGER, intent(in) :: n
  shape_dims(1) = n
  start_dims(1) = 0
  count_dims(1) = n
END SUBROUTINE get_adios_shape

FUNCTION init_adios_t(this, fname, mode) result(ierr)
  IMPLICIT NONE
  CLASS(AdiosWriter_t) :: this
  INTEGER :: ierr
  CHARACTER(*), intent(in) :: fname
  INTEGER, optional :: mode
  INTEGER :: mode_

  IF (present(mode)) THEN
    mode_ = mode
  else
    mode_ = adios2_mode_write
  END IF

  CALL adios2_init(this % adios, parenv % activecomm, ierr)
  CALL adios2_declare_io(this % io, this % adios, "ioWriter", ierr)
  CALL adios2_open(this % engine, this % io, fname, mode_, ierr)
  this % finalized = .false.

END FUNCTION init_adios_t

FUNCTION finalize_adios_t(this) result(ierr)
  IMPLICIT NONE
  CLASS(AdiosWriter_t) :: this
  INTEGER :: ierr
  print *, 'called finalize ', parenv % mype
  IF (.NOT. this % finalized) THEN
    print *, 'finalizing ', parenv % mype
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

  adios_varname = "part_" // i2s(ParEnv % MyPE) // "/" // trim(varname)

  CALL get_adios_shape(size(x,1), shape_dims, start_dims, count_dims)
  CALL adios2_define_variable(var, this%io, adios_varname, adios2_type_integer4, 1, &
    shape_dims, start_dims, count_dims, adios2_constant_dims, ierr)
  CALL adios2_put(this%engine, var, x, ierr)

  END SUBROUTINE writer_integer_t

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
