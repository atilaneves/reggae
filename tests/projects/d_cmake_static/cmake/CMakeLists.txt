cmake_minimum_required(VERSION 3.12)
project(CalculatorStatic)

set(CMAKE_CXX_STANDARD 17)

# Add the source and header directories
include_directories(${CMAKE_SOURCE_DIR}/include)

# Create a static library target
add_library(CalculatorStatic STATIC
    src/Calculator.cpp
)
