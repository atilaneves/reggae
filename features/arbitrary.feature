Feature: Arbritrary rules
  As a D programmer
  I want to specify arbritrary dependencies in a DAG and have them built
  So that I can easily have 100% correct builds

  Background:
    Given a file named "path/to/reggaefile.d" with:
      """
      import reggae;
      const mainObj  = Target(`main.o`,  `dmd -I$project/src -c $in -of$out`, Target(`src/main.d`));
      const mathsObj = Target(`maths.o`, `dmd -c $in -of$out`, Target(`src/maths.d`));
      const app = Target(`myapp`,
                         `dmd -of$out $in`,
                         [mainObj, mathsObj],
                         );
      mixin build!(app);
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
      const mainObj  = Target(`main.o`, `dmd -I$project -c $in -of$out`, Target(`source/main.d`));
      const fooObj   = Target(`foo.o`,  `dmd -c $in -of$out`, Target(`source/foo.d`));
      const app = Target(`appp`,
                         `dmd -of$out $in`,
                         [mainObj, fooObj],
                         );
      mixin build!(app);
      """
    And a file named "different/path/source/main.d" with:
      """
      import std.stdio;
      import source.foo;
      void main(string[] args) {
          writeln(`Appending to `, args[1], ` yields `, appender(args[1]));
      }
      """
    And a file named "different/path/source/foo.d" with:
      """
      module source.foo;
      string appender(string str) { return str ~ ` appended!`; }
      """

  Scenario: Make backend for 1st example
    When I successfully run `reggae -b make path/to`
    And a file named "Makefile" should exist
    When I successfully run `make`
    And the following files should exist:
      |objs/myapp.objs/main.o|
      |objs/myapp.objs/maths.o|
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

  Scenario: Ninja backend for 1st example
    When I successfully run `reggae -b ninja path/to`
    And the following files should exist:
      |build.ninja|
      |rules.ninja|
    When I successfully run `ninja`
    And the following files should exist:
      |objs/myapp.objs/main.o|
      |objs/myapp.objs/maths.o|
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

  Scenario: Binary backend for 1st example
    When I successfully run `reggae -b binary path/to`
    And the following files should exist:
      |build|
    When I successfully run `./build`
    And the following files should exist:
      |objs/myapp.objs/main.o|
      |objs/myapp.objs/maths.o|
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
    When I successfully run `reggae -b make different/path`
    And a file named "Makefile" should exist
    When I successfully run `make`
    And the following files should exist:
      |objs/appp.objs/main.o |
      |objs/appp.objs/foo.o|
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

  Scenario: Ninja backend for 2nd example
    When I successfully run `reggae -b ninja different/path`
    When I successfully run `ninja`
    And the following files should exist:
      |build.ninja|
      |rules.ninja|
    And the following files should exist:
      |objs/appp.objs/main.o|
      |objs/appp.objs/foo.o|
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
