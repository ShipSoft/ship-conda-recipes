cmake_minimum_required(VERSION 3.31)
project(phlex_consumer LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(phlex REQUIRED)

add_library(consumer MODULE consumer.cpp)
target_link_libraries(consumer PRIVATE phlex::module)
