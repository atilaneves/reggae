#include <iostream>
#include <cstdlib> // Include for std::atoi
#include "Calculator.h"

int main(int argc, char *argv[]) {
    int num1 = std::atoi(argv[1]);
    int num2 = std::atoi(argv[2]);

    std::cout << add(num1, num2) << std::endl;
    std::cout << subtract(num1, num2) << std::endl;
    std::cout << multiply(num1, num2) << std::endl;

    return 0;
}
