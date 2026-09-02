cmake_minimum_required(VERSION 3.10)
PROJECT(ElmerPost Fortran C CXX)

SET(CMAKE_MODULE_PATH ${CMAKE_ROOT}/Modules "${PROJECT_SOURCE_DIR}/cmake/Modules" )

SET(ELMER_POST_DATADIR "share/elmerpost")

ADD_DEFINITIONS(-DUSE_ISO_C_BINDINGS)

# MATC is a submodule rather than a copy of its sources. Checked before
# anything else, because the failure otherwise is a missing CMake target
# rather than a sentence saying what to do about it.
IF(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/matc/CMakeLists.txt")
  MESSAGE(FATAL_ERROR
    "The matc submodule is not checked out. Clone with\n"
    "  git clone --recurse-submodules <url>\n"
    "or run\n"
    "  git submodule update --init")
ENDIF()

# MINGW32 has to be a compile definition, and it has to be set before any
# ADD_SUBDIRECTORY, because ADD_DEFINITIONS only reaches targets created after
# it. The IF(MINGW) block further down sets a CMake cache variable of the same
# name, which the preprocessor never sees. In the Elmer tree that did not
# matter, because the root CMakeLists.txt passes -DMINGW32 itself at line 726.
# On its own this repository inherits nothing, so all 21 "#ifdef MINGW32"
# guards in the sources take the Unix branch and pull in GL/glx.h and X11 on
# Windows.
IF(MINGW)
  ADD_DEFINITIONS(-DMINGW32)
ENDIF()

# C99, for the same reason Elmer's root CMakeLists.txt sets it at line 78.
#
# ElmerPost declares functions with an empty parameter list, "void initglp()",
# and calls them with arguments. In C17 and earlier that means "unspecified
# arguments" and is legal; C23 redefines () as (void), so a compiler
# defaulting to C23 rejects every such call. GCC 15 does.
#
# This is not only the bundled MATC's problem, which is how it first appeared:
# gra_set_projection, gra_cylinder, initglp and the six user_hook_* callbacks
# in ElmerPost's own sources are declared the same way. Declaring the standard
# the code was written against is the honest fix; adding prototypes to a
# hundred thousand lines is a separate piece of work.
IF(NOT CMAKE_C_STANDARD)
  SET(CMAKE_C_STANDARD 99)
  SET(CMAKE_C_STANDARD_REQUIRED ON)
ENDIF()

include(CheckIncludeFiles)
CHECK_INCLUDE_FILES(strings.h HAVE_STRINGS_H)
CHECK_INCLUDE_FILES(string.h HAVE_STRING_H)

#SET(TCL_VERSION_STRING 8.5)
#SET(TCLSH_VERSION_STRING 8.5)
FIND_PACKAGE(TCL REQUIRED) # This finds Tk too
FIND_PACKAGE(OpenGL REQUIRED)
SET(USE_INTERP_RESULT TRUE)

MESSAGE(STATUS "OPENGL_LIBRARIES = ${OPENGL_LIBRARIES}")
MESSAGE(STATUS "TCL_LIBRARY = ${TCL_LIBRARY}")
MESSAGE(STATUS "TCL_INCLUDE_PATH = ${TCL_INCLUDE_PATH}")
MESSAGE(STATUS "TK_LIBRARY = ${TK_LIBRARY}")
MESSAGE(STATUS "TK_INCLUDE_PATH = ${TK_INCLUDE_PATH}")

SET(FC_STDCALLBULL " " )
SET(STDCALLBULL TRUE)
#cmakedefine STDCALLBULL @FC_STDCALLBULL@
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/config.h.cmake ${CMAKE_CURRENT_BINARY_DIR}/config.h)

INCLUDE_DIRECTORIES(${CMAKE_CURRENT_BINARY_DIR}/src)
INCLUDE_DIRECTORIES(${CMAKE_CURRENT_SOURCE_DIR}/matc/src)
INCLUDE_DIRECTORIES(${CMAKE_CURRENT_SOURCE_DIR}/src)


# Static, so ElmerPost is one binary rather than a program plus a DLL that
# nothing else uses. MATC defaults to a shared library because Elmer's solver
# wants one; built shared here, ElmerPost links and then exits 0xC0000135 at
# startup because the DLL is not beside it.
#
# The option is named for MATC's command line tool rather than for the library,
# which is confusing when the library is the reason to set it. Honouring the
# standard BUILD_SHARED_LIBS would be better. Noted rather than changed here,
# since that is the other repository's decision.
SET(MATC_STATIC_CLI ON CACHE BOOL "" FORCE)

IF(NOT(TARGET matc))
  add_subdirectory(matc)
ENDIF(NOT(TARGET matc))
add_subdirectory(src)

SET_PROPERTY(DIRECTORY src PROPERTY INCLUDE_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}/src" "${CMAKE_CURRENT_BINARY_DIR}/src" "${CMAKE_CURRENT_SOURCE_DIR}/matc/src")

INSTALL(DIRECTORY "doc/" DESTINATION "${ELMER_POST_DATADIR}/help" COMPONENT ElmerPost)
INSTALL(FILES "tcl_license.terms" "tk_license.terms" DESTINATION "${ELMER_POST_DATADIR}/licenses" COMPONENT ElmerPost)

IF(MINGW)
  SET(MINGW32 TRUE CACHE BOOL "")
  MESSAGE(STATUS "MING32 detected")
  MESSAGE(WARNING "Installing (tcl|tk)_include_path/../(bin|lib)/")
  INSTALL(DIRECTORY "${TCL_INCLUDE_PATH}/../bin/" DESTINATION "bin")
  INSTALL(DIRECTORY "${TCL_INCLUDE_PATH}/../lib/" DESTINATION "lib")
  INSTALL(DIRECTORY "${TK_INCLUDE_PATH}/../bin/" DESTINATION "bin")
  INSTALL(DIRECTORY "${TK_INCLUDE_PATH}/../lib/" DESTINATION "lib")
ENDIF(MINGW)


########### install files ###############




#original Makefile.am contents follow:

#SUBDIRS=src
