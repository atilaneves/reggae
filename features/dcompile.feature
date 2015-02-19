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
      import reggae;
      const mainObj  = dCompile(`source/main.d`,  ``, [`source`]);
      const mathsObj = dCompile(`source/maths.d`, ``, [`source`]);
      const ioObj    = dCompile(`source/io.d`,    ``, [`source`]);
      mixin build!(Target(`calc`, `dmd -of$out $in`, [mainObj, mathsObj, ioObj]));
      """

  Scenario: Using dcompile for every object file with Ninja
    When I successfully run `reggae -b ninja leproj`
    And I successfully run `ninja`
    And I run `./calc 5`
    Then the output should contain:
      """
      output: The result of 5 is 120
      """
    Given I successfully run `sleep 1` for up to 1 seconds
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
    Given I successfully run `sleep 1` for up to 1 seconds
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
    Given I successfully run `sleep 1` for up to 1 seconds
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

  Scenario: Using dcompile for every object file with Make
    When I successfully run `reggae -b make leproj`
    And I successfully run `make`
    And I run `./calc 5`
    Then the output should contain:
      """
      output: The result of 5 is 120
      """
    Given I successfully run `sleep 1` for up to 1 seconds
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
    Given I successfully run `sleep 1` for up to 1 seconds
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
    Given I successfully run `sleep 1` for up to 1 seconds
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
