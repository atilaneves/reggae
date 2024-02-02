cmake_minimum_required(VERSION 3.12)
project(CalculatorAppShared)

set(CMAKE_CXX_STANDARD 17)

# Add the source and header directories
include_directories(${CMAKE_SOURCE_DIR}/include)

# Create a shared library target
add_library(CalculatorShared SHARED
    src/Calculator.cpp
)

target_include_directories(CalculatorShared PRIVATE ${CMAKE_SOURCE_DIR}/include)

target_compile_definitions(CalculatorShared PRIVATE MYDLL_EXPORTS)

# Add the executable target that uses the shared library
add_executable(CalculatorAppShared
    src/main.cpp
)

# Link the executable with the shared library
target_link_libraries(CalculatorAppShared PRIVATE CalculatorShared)