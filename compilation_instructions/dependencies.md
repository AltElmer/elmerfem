Elmer dependencies
==================

Elmer ships copies of several third party libraries so that it builds on a machine with nothing installed. Every one of them can be replaced by a system copy, which is what distribution packagers generally want.

Bundled libraries
-----------------

| library | bundled at | switch to use a system copy | notes |
| --- | --- | --- | --- |
| METIS | `elmergrid/src/metis-5.1.0` | `-DEXTERNAL_METIS=ON` | mesh partitioning, used by ElmerGrid |
| UMFPACK | `umfpack/` | `-DEXTERNAL_UMFPACK=ON` | part of SuiteSparse; enabled by `WITH_UMFPACK`, which is `ON` by default. See the note below |
| ARPACK | `mathlibs/src/arpack` | `-DEXTERNAL_ARPACK=ON` | eigenvalue solver |
| PARPACK | `mathlibs/src/parpack` | `-DEXTERNAL_PARPACK=ON` | parallel ARPACK; only used with MPI |
| Lua | `contrib/lua-5.1.5` | `-DEXTERNAL_LUA=ON` | only used when `WITH_LUA=ON`; Lua 5.1 specifically |
| Zoltan | `contrib/Zoltan_v3.83` | `-DEXTERNAL_ZOLTAN=ON` | a git submodule, not vendored source; only used when `WITH_Zoltan=ON` |
| BLAS, LAPACK | `mathlibs/src/blas`, `mathlibs/src/lapack` | `-DBLA_VENDOR=...` | CMake's own mechanism, for example `-DBLA_VENDOR=OpenBLAS` |

`EXTERNAL_LUA` and `EXTERNAL_ZOLTAN` used to be spelled `USE_SYSTEM_LUA` and `USE_SYSTEM_ZOLTAN`. The old names still work and print a deprecation warning.

A note on the bundled UMFPACK
-----------------------------

The bundled copy is UMFPACK 5.1, which is deliberate rather than neglect: 5.1 is the last LGPL release, and later SuiteSparse versions are GPL. That matters to users who link Elmer against modules of their own that are not open source, and it is why the bundled copy has not simply been updated.

It does mean the bundled copy is from 2007 and does not carry the fixes made upstream since, so anyone without that licensing constraint is better served by a current SuiteSparse via `-DEXTERNAL_UMFPACK=ON`. UMFPACK's own `Doc/ChangeLog` in [SuiteSparse](https://github.com/DrTimothyAldenDavis/SuiteSparse) lists what has changed.

Building without UMFPACK at all is also supported, see #578 and #579.

Because `contrib/Zoltan_v3.83` is a submodule, a plain `git clone` leaves it empty. Clone with `--recurse-submodules`, or run `git submodule update --init` afterwards, if you intend to build with `WITH_Zoltan=ON` and without `EXTERNAL_ZOLTAN`.

Libraries that are never bundled
--------------------------------

These are found on the system or not used at all. Each is off by default unless noted.

| library | switch | notes |
| --- | --- | --- |
| MPI | `WITH_MPI` | on by default |
| OpenMP | `WITH_OpenMP` | |
| MUMPS | `WITH_Mumps` | |
| Hypre | `WITH_Hypre` | |
| CHOLMOD | `WITH_CHOLMOD` | part of SuiteSparse |
| Trilinos | `WITH_Trilinos` | |
| MMG, ParMMG | `WITH_MMG`, `WITH_PARMMG` | remeshing |
| ROCALUTION | `WITH_ROCALUTION` | |
| NetCDF | `WITH_NETCDF` | |
| XIOS | `WITH_XIOS` | |
| Qt 5 or 6, Qwt | `WITH_ELMERGUI` with `WITH_QT5` or `WITH_QT6` | ElmerGUI only |
| VTK | `WITH_VTK` | ElmerGUI VtkPost only |
| OpenCASCADE | `WITH_OCC` | ElmerGUI CAD import only |
| MATC | `WITH_MATC` | ElmerGUI; `ELMERGRID_WITH_MATC` for ElmerGrid |

Building against system libraries
---------------------------------

On Debian or Ubuntu:

```
sudo apt-get install cmake gfortran g++ gcc ninja-build \
     libopenblas-dev libblas-dev liblapack-dev libopenmpi-dev \
     libmetis-dev libsuitesparse-dev liblua5.1-0-dev

cmake -S . -B build -G Ninja \
      -DBLA_VENDOR=OpenBLAS \
      -DEXTERNAL_METIS=ON -DEXTERNAL_UMFPACK=ON \
      -DWITH_LUA=ON -DEXTERNAL_LUA=ON
cmake --build build
```

`EXTERNAL_ARPACK` and `EXTERNAL_PARPACK` are left out of that example on purpose. Debian and Ubuntu ship an `arpack-ng` CMake config whose `include()` of its own targets file fails, and the resulting errors are raised inside `FIND_PACKAGE` before this project can react to them, so configure aborts. Distributions that package arpack-ng correctly are unaffected.

On MSYS2 the equivalent is exercised by the `build-windows-mingw` workflow, which builds both bundled and external in the same matrix. The `ubuntu-external-deps` workflow does the same on Linux.

Checking which copy is actually used
------------------------------------

The switches are ordinary cache variables, so the configured state can be read back:

```
grep -E '^EXTERNAL_[A-Z]+:BOOL' build/CMakeCache.txt
```

This is worth doing after changing them. A switch set on the command line but not honoured leaves the bundled copy in use, and the build otherwise looks the same.
