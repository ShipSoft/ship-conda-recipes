cmake_minimum_required(VERSION 3.25)
project(mp_units_consumer LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(mp-units 2.5 CONFIG REQUIRED)

add_executable(mp_units_consumer main.cpp)
target_link_libraries(mp_units_consumer PRIVATE mp-units::mp-units)

# conda-forge's libc++ 20 headers misspell the LLVM 20 availability attribute,
# so C++20 code that pulls in <charconv> (here via <chrono>) fails on macOS.
# The runtime is conda's libcxx, so the availability markup can be turned off.
if(APPLE)
  target_compile_definitions(mp_units_consumer PRIVATE _LIBCPP_DISABLE_AVAILABILITY)
endif()
