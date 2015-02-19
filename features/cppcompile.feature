Feature: C++ compilation rule
  As a reggae user
  I want to have reggae determine the implicit dependencies when compiling a single C++ file
  So that I don't have to specify the dependencies myself

  Background:
    Given a file named "mixproj/src/d/main.d" with:
      """
      extern(C++) int calc(int i);
      import std.stdio;
      import std.conv;
      void main(string[] args) {
          immutable number = args[1].to!int;
          immutable result = calc(number);
          writeln(`The result of calc(`, number, `) is `, result);
      }
      """

    And a file named "mixproj/src/cpp/maths.cpp" with:
      """
      #include "maths.hpp"
      int calc(int i) {
          return i * factor;
      }
      """
    And a file named "mixproj/headers/maths.hpp" with:
      """
      const int factor = 3;
      """
    And a file named "mixproj/reggaefile.d" with:
      """
      import reggae;
      const mainObj  = dCompile(`src/d/main.d`);
      const mathsObj = cppCompile(`src/cpp/maths.cpp`, ``, [`headers`]);
      mixin build!(Target(`calc`, `dmd -of$out $in`, [mainObj, mathsObj]));
      """

  Scenario: Mixing C++ and D files with Ninja
    When I successfully run `reggae -b ninja mixproj`
    And I successfully run `ninja`
    And I successfully run `./calc 5`
    Then the output should contain:
      """
      The result of calc(5) is 15
      """
    Given I successfully run `sleep 1` for up to 1 seconds
    And I overwrite "mixproj/headers/maths.hpp" with:
      """
      const int factor = 10;
      """
    When I successfully run `ninja`
    And I successfully run `./calc 3`
    Then the output should contain:
      """
      The result of calc(3) is 30
      """

  Scenario: Mixing C++ and D files with Make
    When I successfully run `reggae -b make mixproj`
    And I successfully run `make`
    And I successfully run `./calc 5`
    Then the output should contain:
      """
      The result of calc(5) is 15
      """
    Given I successfully run `sleep 1` for up to 1 seconds
    And I overwrite "mixproj/headers/maths.hpp" with:
      """
      const int factor = 10;
      """
    When I successfully run `make`
    And I successfully run `./calc 3`
    Then the output should contain:
      """
      The result of calc(3) is 30
      """
