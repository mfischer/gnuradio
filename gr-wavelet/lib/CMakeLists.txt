# Copyright 2012 Free Software Foundation, Inc.
#
# This file is part of GNU Radio
#
# GNU Radio is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.
#
# GNU Radio is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with GNU Radio; see the file COPYING.  If not, write to
# the Free Software Foundation, Inc., 51 Franklin Street,
# Boston, MA 02110-1301, USA.

########################################################################
# Setup the include and linker paths
########################################################################
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_BINARY_DIR}
    ${GR_WAVELET_INCLUDE_DIRS}
    ${GNURADIO_CORE_INCLUDE_DIRS}
    ${GRUEL_INCLUDE_DIRS}
    ${Boost_INCLUDE_DIRS}
    ${GSL_INCLUDE_DIRS}
)

link_directories(${WAVELET_LIBRARY_DIRS})
link_directories(${Boost_LIBRARY_DIRS})
link_directories(${GSL_LIBRARY_DIRS})
add_definitions(${GSL_DEFINITIONS})

include_directories(${LOG4CPP_INCLUDE_DIRS})
link_directories(${LOG4CPP_LIBRARY_DIRS})

########################################################################
# Setup library
########################################################################
list(APPEND gr_wavelet_sources
    wavelet_squash_ff_impl.cc
    wavelet_wavelet_ff_impl.cc
    wavelet_wvps_ff_impl.cc
)

#Add Windows DLL resource file if using MSVC
if(MSVC)
    include(${CMAKE_SOURCE_DIR}/cmake/Modules/GrVersion.cmake)

    configure_file(
        ${CMAKE_CURRENT_SOURCE_DIR}/gnuradio-wavelet.rc.in
        ${CMAKE_CURRENT_BINARY_DIR}/gnuradio-wavelet.rc
    @ONLY)

    list(APPEND gr_wavelet_sources
        ${CMAKE_CURRENT_BINARY_DIR}/gnuradio-wavelet.rc
    )
endif(MSVC)

list(APPEND wavelet_libs
    gnuradio-core
    ${Boost_LIBRARIES}
    ${WAVELET_LIBRARIES}
    ${GSL_LIBRARIES}
    ${LOG4CPP_LIBRARIES}
)

add_library(gnuradio-wavelet SHARED ${gr_wavelet_sources})
target_link_libraries(gnuradio-wavelet ${wavelet_libs})
GR_LIBRARY_FOO(gnuradio-wavelet RUNTIME_COMPONENT "wavelet_runtime" DEVEL_COMPONENT "wavelet_devel")
