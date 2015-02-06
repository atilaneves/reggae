Feature: Arbritrary rules
  As a D programmer
  I want to specify arbritrary dependencies in a DAG and have them built
  So that I can easily have 100% correct builds

  Background:
    Given a file named "path/to/reggaefile.d" with:
      """
      import reggae;
      const mainObj  = Target(`main.o`,  leaf(`main.d`),  [`dmd`, `-c`, `main.d`,  `-ofmain.o`]);
      const mathsObj = Target(`maths.o`, leaf(`maths.d`), [`dmd`, `-c`, `maths.d`, `-ofmaths.o`]);
      const app = Target(`myapp`,
                         [mainObj, mathsObj],
                         [`dmd` ,`-ofmyapp`, `main.o`, `maths.o`]
                         )
      """
    And a file named "path/to/src/main.d" with:
      """
      import maths;
      import std.stdio;
      import std.conv;
      void main(string[] args) {
          const a = args[1].to!int;
          const b = args[2].to!int;
          writeln(`The sum     of `, a, ` and `, b, ` is `, adder(a, b));
          writeln(`The product of `, a, ` and `, b, ` is `, prodder(a, b));
      }
      """
    And a file named "path/to/src/maths.d" with:
      """
      int adder(int a, int b) { return a + b; }
      int prodder(int a, int b) { return a * b; }
      """

  Scenario: Backend is make
    When I run `reggae path/to`
    Then the exit status should be 0
    And a file named "Makefile" should exist
    When I run `make`
    Then the exit status should be 0
    And the following files should exist:
      |main.o|
      |maths.o|
      |myapp|
    When I run `./myapp 2 3`
    Then the output should contain:
      """
      The sum     of 2 and 3 is 5
      The product of 2 and 3 is 6
      """
    When I run `./myapp 3 4`
    Then the output should contain:
      """
      The sum     of 3 and 4 is 7
      The product of 3 and 4 is 12
      """
