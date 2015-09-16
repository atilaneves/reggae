Feature: Unity builds for C and C++
  As a reggae user
  I want to have unity builds automatically generated
  So I can have faster builds

  Background:
    Given a file named "project/reggaefile.d" with:
      """
      import reggae;
      alias app = unityBuild!(ExeName(`unity`),
                              Sources!([`src`]),
                              Flags(`-g`));
      mixin build!app;
      """

    And a file named "project/src/main.cpp" with:
      """
      #include <iostream>
      extern int timesTwo(int);
      using namespace std;
      int main() {
          const int i = 3;
          cout << i << " times two is " << timesTwo(i) << endl;
      }
      """

    And a file named "project/src/maths.cpp" with:
      """
      int timesTwo(int i) { return i * 2; }
      """

  @make
  Scenario: Unity build with make
    Given I successfully run `reggae -b make project`
    Then a file named "objs/unity.objs/unity.cpp" should exist

    Given I successfully run `make`
    When I successfully run `./unity`
    Then the output should contain:
      """
      3 times two is 6
      """

  @ninja
  Scenario: Unity build with ninja
    Given I successfully run `reggae -b ninja project`
    Then a file named "objs/unity.objs/unity.cpp" should exist

    Given I successfully run `ninja`
    When I successfully run `./unity`
    Then the output should contain:
      """
      3 times two is 6
      """
