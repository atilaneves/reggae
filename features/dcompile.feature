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
          auto result = factorial(number);
          println(`The factorial of `, number, ` is `, result);
      }
      """

    And a file named "leproj/source/maths.d" with:
      """
      int factorial(int n) { return n > 0 ? n * factorial(n - 1) : 1; }
      """

    And a file named "leproj/source/io.d" with:
      """
      import std.stdio;
      void println(T...)(T args) { writeln(`output: `, args); }
      """

    And a file named "leproj/reggaefile.d" with:
      """
      import reggae;
      const mainObj = dcompile(`source/main.d`, [`source`]);
      const mathsObj = dcompile(`source/maths.d`, [`source`]);
      const ioObj = dcompile(`source/io.d`, [`source`]);
      const b = Build(Target(`fac`, `dmd -of$out $in`, [mainObj, mathsObj, ioObj]));
      """

    When I run `reggae -b ninja leproj`
    Then the exit status should be 0
    When I run `ninja`
    Then the exit status should be 0
    When I run `./fac 5`
    Then the output should contain:
      """
      output: The factorial of 5 is 120
      """
