Feature: Linking a D executable
  As a reggae user
  I want reggae to determine all dependencies to build a D executable
  So that I can easily build one

  Scenario: Mixed C++/D build
    Given a file named "linkproj/d/main.d" with:
      """
      extern(C++) int calc(int i, int j);
      import std.stdio;
      import std.conv;
      import logger;
      void main(string[] args) {
          immutable a = args[1].to!int;
          immutable b = args[2].to!int;
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
      int calc(int i, int j) {
          return i * 2 + j;
      }
      """
    And a file named "linkproj/reggaefile.d" with:
      """
      import reggae;
      const mathsObj = cppCompile(`cpp/maths.cpp`);
      Build bld;
      shared static this() {
          bld = Build(dExe(`d/main.d`, ``, [`d`], [], [mathsObj]));
      }
      """

    When I successfully run `reggae -b ninja linkproj`
    And I successfully run `ninja`
    And I successfully run `./main 2 3`
    Then the output should contain:
      """
      Logger says... woohoo The result of feeding 2 and 3 to C++ is 7
      """

    Given I successfully run `sleep 1` for up to 1 seconds
    And I overwrite "linkproj/d/constants.d" with:
      """
      immutable myconst = `ohnoes`;
      """
    When I successfully run `ninja`
    And I successfully run `./main 7 10`
    Then the output should contain:
      """
      Logger says... ohnoes The result of feeding 7 and 10 to C++ is 24
      """
