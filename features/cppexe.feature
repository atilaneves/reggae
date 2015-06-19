Feature: Using executable for a C++ project
  As a reggae user
  I want to use the executable high-level rule for C++
  So I don't have to explicitly tell the system what I want

  Background:
    Given a file named "proj/main.cpp" with:
      """
      #include "intermediate.hpp"
      #include <iostream>
      extern int timesTwo(int);
      using namespace std;
      int main() {
          const int i = 3;
          cout << i << "times two is " << timesTwo(i) << endl;
          cout << STUFF << endl;
      }
      """

    And a file named "proj/maths.cpp" with:
      """
      int timesTwo(int i) { return i * 2; }
      """
    And a file named "proj/intermediate.hpp" with:
      """
      #include "final.hpp"
      """
    And a file named "proj/final.hpp" with:
      """
      #define STUFF 42
      """
    And a file named "proj/reggaefile.d" with:
      """
      import reggae;
      alias app = executable!(App(`main.cpp`, `app`),
                              Flags(`-g -O0`),
                              IncludePaths([`.`]));
      mixin build!app;
      """

    @ninja
    Scenario: Ninja
      Given I successfully run `reggae -b ninja proj`
      And I successfully run `ninja`
      When I successfully run `./app`
      Then the output should contain:
        """
        3 times two is 6
        42
        """
