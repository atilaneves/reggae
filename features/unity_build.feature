Feature: Unity builds for C and C++
  As a reggae user
  I want to have unity builds automatically generated
  So I can have faster builds

  @make
  Scenario:
    Given a file named "project/reggaefile.d" with:
      """
      import reggae;
      alias objs = unityBuild!(Sources!([`src`]));
      alias app = link!(ExeName(`unity`), objs);
      mixin build!app;
      """

    And a file named "project/src/main.cpp" with:
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

    When I successfully run `reggae -b make project`
    Then a file named "unity.cpp" should exist

    When I successfully run `cat unity.cpp`
    Then the output should contain:
    """
    #include "main.cpp"
    #include "maths.cpp"
    """

    When I successfully run `make`
    Then a file named "objs/unity.objs/unity.o" should exist

    When I successfully run `./unity`
    Then the output should contain:
      """
      3 times two is 6
      """
