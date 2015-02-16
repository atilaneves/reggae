Feature: D compilation rule
  As a reggae user
  I want to have reggae determine the implicit dependencies when compiling a single D file
  So that I don't have to specify the dependencies myself

  Scenario: Using dcompile for every object file
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
      Build b;
      shared static this() {
          const mainObj = dcompile(`source/main.d`, [`source`]);
          const mathsObj = dcompile(`source/maths.d`, [`source`]);
          const ioObj = dcompile(`source/io.d`, [`source`]);
          b = Build(Target(`calc`, `dmd -of$out $in`, [mainObj, mathsObj, ioObj]));
      }
      """

    When I successfully run `reggae -b ninja leproj`
    And I successfully run `ninja`
    And I run `./calc 5`
    Then the output should contain:
      """
      output: The result of 5 is 120
      """
    Given a file named "leproj/source/constants.d" with:
      """
      immutable int leconst = 2;
      """
    And I run `touch leproj/source/constants.d`
    And I run `touch leproj/source/constants.d`
    And I run `touch leproj/source/constants.d`
    When I successfully run `ninja`
    And I successfully run `./calc 5`
    Then the output should contain:
      """
      output: The result of 5 is 10
      """
    Given a file named "leproj/source/constants.d" with:
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
    Given a file named "leproj/source/generator.d" with:
      """
      int constInt() { return 6; }
      """
    When I successfully run `touch leproj/source/generator.d`
    When I successfully run `touch leproj/source/generator.d`
    When I successfully run `touch leproj/source/generator.d`
    And I successfully run `ninja`
    And I successfully run `./calc 7`
    Then the output should contain:
      """
      output: The result of 7 is 42
      """
