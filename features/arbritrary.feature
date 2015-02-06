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
      const build = Build(app);
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
    And a file named "different/path/reggaefile.d" with:
      """
      import reggae;
      const mainObj  = Target(`main.o`,  leaf(`main.d`),  [`dmd`, `-c`, `main.d`,  `-ofmain.o`]);
      const fooObj   = Target(`maths.o`, leaf(`foo.d`),   [`dmd`, `-c`, `foo.d`,   `-offoo.o`]);
      const app = Target(`appp`,
                         [mainObj, mathsObj],
                         [`dmd` ,`-ofappp`, `main.o`, `foo.o`]
                         )
      const build = Build(app);
      """
    And a file named "different/path/source/main.d" with:
      """
      import std.stdio;
      import foo;
      void main(string[] args) {
          writeln(`Appending to `, args[1], ` yields `, appender(args[1]));
      }
      """
    And a file named "different/path/source/foo.d" with:
      """
      string appender(string str) { return str ~ ` appended!`}
      """

  Scenario: Make backend for 1st example
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

  Scenario: Make backend for 2nd example
    When I run `reggae different/path`
    Then the exit status should be 0
    And a file named "Makefile" should exist
    When I run `make`
    Then the exit status should be 0
    And the following files should exist:
      |main.o|
      |foo.o|
      |appp|
    When I run `./appp hello`
    Then the output should contain:
      """
      Appending to hello yields hello appended!
      """
    When I run `./appp ohnoes`
    Then the output should contain:
      """
      Appending to ohnoes yields ohnoes appended!
      """
