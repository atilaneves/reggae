Feature: Linking a D executable
  As a reggae user
  I want reggae to determine all dependencies to build a D executable
  So that I can easily build one

  Background:
    Given a file named "linkproj/d/main.d" with:
      """
      extern(C++) int calc(int i, int j);
      import std.stdio;
      import std.conv;
      import logger;
      void main(string[] args) {
          immutable a = args[1].to!int;
          immutable b = args[2].to!int;
          writeln(import(`banner.txt`));
          log(`The result of feeding `, a, ` and `, b, ` to C++ is `, calc(a, b));
      }
      """
    And a file named "linkproj/d/logger.d" with:
      """
      import constants;
      import std.stdio;
      void log(T...)(T args) {
          writeln(`Logger says... `, myconst, " ", args);
      }
      """
    And a file named "linkproj/d/constants.d" with:
      """
      immutable myconst = `woohoo`;
      """
    And a file named "linkproj/cpp/maths.cpp" with:
      """
      extern int factor();
      int calc(int i, int j) {
          return i * factor() + j;
      }
      """
    And a file named "linkproj/extra/constants.cpp" with:
      """
      int factor() { return 2; }
      """
    And a file named "linkproj/cpp/extra_main.cpp" with:
      """
      int main() {
      }
      """
    And a file named "linkproj/resources/text/banner.txt" with:
      """
      Bannerarama!
      """
    And a file named "linkproj/reggaefile.d" with:
      """
      import reggae;

      alias cppSrcs = Sources!(Dirs([`cpp`]),
                               Files([`extra/constants.cpp`]),
                               Filter!(a => a != `cpp/extra_main.cpp`));
      alias cppObjs = targetsFromSources!(cppSrcs, Flags(`-pg`));

      alias app = executable!(App(`d/main.d`, `calc`),
                              Flags(`-debug -O`),
                              ImportPaths([`d`]),
                              StringImportPaths([`resources/text`]),
                              cppObjs,
                              );
      mixin build!(app);
      """

  @ninja
  Scenario: Ninja backend
    When I successfully run `reggae -b ninja linkproj`
    And I successfully run `ninja`
    Then the output should contain:
      """
      -debug -O
      """
    And the output should contain:
      """
      -pg
      """
    When I successfully run `./calc 2 3`
    Then the output should contain:
      """
      Bannerarama!
      Logger says... woohoo The result of feeding 2 and 3 to C++ is 7
      """

    Given I successfully run `sleep 1` for up to 2 seconds
    And I overwrite "linkproj/d/constants.d" with:
      """
      immutable myconst = `ohnoes`;
      """
    When I successfully run `ninja`
    And I successfully run `./calc 7 10`
    Then the output should contain:
      """
      Logger says... ohnoes The result of feeding 7 and 10 to C++ is 24
      """

  @make
  Scenario: Make backend
    When I successfully run `reggae -b make linkproj`
    And I successfully run `make`
    Then the output should contain:
      """
      -debug -O
      """
    And the output should contain:
      """
      -pg
      """
    When I successfully run `./calc 2 3`
    Then the output should contain:
      """
      Bannerarama!
      Logger says... woohoo The result of feeding 2 and 3 to C++ is 7
      """

    Given I successfully run `sleep 1` for up to 2 seconds
    And I overwrite "linkproj/d/constants.d" with:
      """
      immutable myconst = `ohnoes`;
      """
    When I successfully run `make`
    And I successfully run `./calc 7 10`
    Then the output should contain:
      """
      Logger says... ohnoes The result of feeding 7 and 10 to C++ is 24
      """

  @binary
  Scenario: Binary backend
    When I successfully run `reggae -b binary linkproj`
    And I successfully run `./build`
    Then the output should contain:
      """
      -debug -O
      """
    And the output should contain:
      """
      -pg
      """
    When I successfully run `./calc 2 3`
    Then the output should contain:
      """
      Bannerarama!
      Logger says... woohoo The result of feeding 2 and 3 to C++ is 7
      """

    Given I successfully run `sleep 1` for up to 2 seconds
    And I overwrite "linkproj/d/constants.d" with:
      """
      immutable myconst = `ohnoes`;
      """
    When I successfully run `./build`
    And I successfully run `./calc 7 10`
    Then the output should contain:
      """
      Logger says... ohnoes The result of feeding 7 and 10 to C++ is 24
      """

  @tup
  Scenario: Tup backend
    When I successfully run `reggae -b tup linkproj`
    And I successfully run `tup upd`
    Then the output should contain:
      """
      -debug -O
      """
    And the output should contain:
      """
      -pg
      """
    When I successfully run `./calc 2 3`
    Then the output should contain:
      """
      Bannerarama!
      Logger says... woohoo The result of feeding 2 and 3 to C++ is 7
      """

    Given I successfully run `sleep 1` for up to 2 seconds
    And I overwrite "linkproj/d/constants.d" with:
      """
      immutable myconst = `ohnoes`;
      """
    When I successfully run `tup upd`
    And I successfully run `./calc 7 10`
    Then the output should contain:
      """
      Logger says... ohnoes The result of feeding 7 and 10 to C++ is 24
      """
