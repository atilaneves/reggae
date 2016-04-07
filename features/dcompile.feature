Feature: D compilation rule
  As a reggae user
  I want to have reggae determine the implicit dependencies when compiling a single D file
  So that I don't have to specify the dependencies myself

  Background:
    Given a file named "leproj/source/main.d" with:
      """
      import maths;
      import io;
      import std.conv;
      void main(string[] args) {
          auto number = args[1].to!int;
          auto result = calc(number);
          println(`The result of `, number, ` is `, result);
      }
      """

    And a file named "leproj/source/maths.d" with:
      """
      import constants;
      int calc(int n) { return n * leconst; }
      """

    And a file named "leproj/source/constants.d" with:
      """
      immutable int leconst = 24;
      """

    And a file named "leproj/source/io.d" with:
      """
      import std.stdio;
      void println(T...)(T args) { writeln(`output: `, args); }
      """

    And a file named "leproj/reggaefile.d" with:
      """
      //constants.d is never mentioned here but changes to it
      //should trigger recompilation
      import reggae;
      enum mainObj  = objectFile(SourceFile(`source/main.d`),  Flags(``), ImportPaths([`source`]));
      enum mathsObj = objectFile(SourceFile(`source/maths.d`), Flags(``), ImportPaths([`source`]));
      enum ioObj    = objectFile(SourceFile(`source/io.d`),    Flags(``), ImportPaths([`source`]));
      mixin build!(Target(`calc`, `dmd -of$out $in`, [mainObj, mathsObj, ioObj]));
      """

  @ninja
  Scenario: Using dcompile for every object file with Ninja
    When I successfully run `reggae -b ninja leproj`
    And I successfully run `ninja`
    And I run `./calc 5`
    Then the output should contain:
      """
      output: The result of 5 is 120
      """
    Given I successfully run `sleep 1` for up to 2 seconds
    And I overwrite "leproj/source/constants.d" with:
      """
      immutable int leconst = 2;
      """
    When I successfully run `ninja`
    And I successfully run `./calc 5`
    Then the output should contain:
      """
      output: The result of 5 is 10
      """
    Given I successfully run `sleep 1` for up to 2 seconds
    And I overwrite "leproj/source/constants.d" with:
      """
      import generator;
      immutable int leconst = constInt();
      """
    And a file named "leproj/source/generator.d" with:
      """
      int constInt() { return  5; }
      """
    When I successfully run `ninja`
    And I successfully run `./calc 5`
    Then the output should contain:
      """
      output: The result of 5 is 25
      """
    Given I successfully run `sleep 1` for up to 2 seconds
    And I overwrite "leproj/source/generator.d" with:
      """
      int constInt() { return 6; }
      """
    When I successfully run `ninja`
    And I successfully run `./calc 7`
    Then the output should contain:
      """
      output: The result of 7 is 42
      """

  @make
  Scenario: Using dcompile for every object file with Make
    When I successfully run `reggae -b make leproj`
    And I successfully run `make`
    And I run `./calc 5`
    Then the output should contain:
      """
      output: The result of 5 is 120
      """
    Given I successfully run `sleep 1` for up to 2 seconds
    And I overwrite "leproj/source/constants.d" with:
      """
      immutable int leconst = 2;
      """
    When I successfully run `make`
    And I successfully run `./calc 5`
    Then the output should contain:
      """
      output: The result of 5 is 10
      """
    Given I successfully run `sleep 1` for up to 2 seconds
    And I overwrite "leproj/source/constants.d" with:
      """
      import generator;
      immutable int leconst = constInt();
      """
    And a file named "leproj/source/generator.d" with:
      """
      int constInt() { return  5; }
      """
    When I successfully run `make`
    And I successfully run `./calc 5`
    Then the output should contain:
      """
      output: The result of 5 is 25
      """
    Given I successfully run `sleep 1` for up to 2 seconds
    And I overwrite "leproj/source/generator.d" with:
      """
      int constInt() { return 6; }
      """
    When I successfully run `make`
    And I successfully run `./calc 7`
    Then the output should contain:
      """
      output: The result of 7 is 42
      """

  @binary
  Scenario: Using dcompile for every object file with Binary
    When I successfully run `reggae -b binary leproj`
    And I successfully run `./build`
    And I run `./calc 5`
    Then the output should contain:
      """
      output: The result of 5 is 120
      """
    Given I successfully run `sleep 1` for up to 2 seconds
    And I overwrite "leproj/source/constants.d" with:
      """
      immutable int leconst = 2;
      """
    When I successfully run `./build`
    And I successfully run `./calc 5`
    Then the output should contain:
      """
      output: The result of 5 is 10
      """
    Given I successfully run `sleep 1` for up to 2 seconds
    And I overwrite "leproj/source/constants.d" with:
      """
      import generator;
      immutable int leconst = constInt();
      """
    And a file named "leproj/source/generator.d" with:
      """
      int constInt() { return  5; }
      """
    When I successfully run `./build`
    And I successfully run `./calc 5`
    Then the output should contain:
      """
      output: The result of 5 is 25
      """
    Given I successfully run `sleep 1` for up to 2 seconds
    And I overwrite "leproj/source/generator.d" with:
      """
      int constInt() { return 6; }
      """
    When I successfully run `./build`
    And I successfully run `./calc 7`
    Then the output should contain:
      """
      output: The result of 7 is 42
      """

    When I successfully run `./build`
    Then the output should contain:
      """
      [build] Nothing to do
      """

  @tup
  Scenario: Using dcompile for every object file with Tup
    When I successfully run `reggae -b tup leproj`
    And I successfully run `tup`
    And I run `./calc 5`
    Then the output should contain:
      """
      output: The result of 5 is 120
      """
