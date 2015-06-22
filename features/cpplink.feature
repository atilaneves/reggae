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
          cout << i << " times two is " << timesTwo(i) << endl;
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
      alias objs = targetsFromSources!(Sources!(), Flags(`-g -O0`));
      //enum app = link(`app`, objs);
      //mixin build!app;
      Build b() {
          return Build(link(`app`, objs));
      }
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

    @make
    Scenario: Make
      Given I successfully run `reggae -b make proj`
      And I successfully run `make`
      When I successfully run `./app`
      Then the output should contain:
        """
        3 times two is 6
        42
        """

    @tup
    Scenario: Tup
      Given I successfully run `reggae -b tup proj`
      And I successfully run `tup`
      When I successfully run `./app`
      Then the output should contain:
        """
        3 times two is 6
        42
        """

    @binary
    Scenario: Binary
      Given I successfully run `reggae -b binary proj`
      And I successfully run `./build`
      When I successfully run `./app`
      Then the output should contain:
        """
        3 times two is 6
        42
        """
