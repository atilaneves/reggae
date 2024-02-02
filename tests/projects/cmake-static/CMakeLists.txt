cmake_minimum_required(VERSION 3.12)
project(CalculatorAppStatic)

set(CMAKE_CXX_STANDARD 17)

# Add the source and header directories
include_directories(${CMAKE_SOURCE_DIR}/include)

# Create a static library target
add_library(CalculatorStatic STATIC
    src/Calculator.cpp
)

# Add the executable target that uses the static library
add_executable(CalculatorAppStatic
    src/main.cpp
)

# Link the executable with the static library
target_link_libraries(CalculatorAppStatic PRIVATE CalculatorStatic)