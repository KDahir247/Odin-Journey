cmake_minimum_required(VERSION 3.28)
project(journey_audio C)

set(CMAKE_C_STANDARD 99)

if(MSVC)
    add_compile_options(
            $<$<CONFIG:>:/MT>
            $<$<CONFIG:Debug>:/MT>
            $<$<CONFIG:Release>:/MT>
    )
endif()

add_library(journey_audio STATIC library.c)

