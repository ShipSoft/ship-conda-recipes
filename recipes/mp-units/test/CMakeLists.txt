cmake_minimum_required(VERSION 3.25)
project(mp_units_consumer LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(mp-units 2.5 CONFIG REQUIRED)

add_executable(mp_units_consumer main.cpp)
target_link_libraries(mp_units_consumer PRIVATE mp-units::mp-units)
