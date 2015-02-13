Feature: Correct dependencies
  As a Reggae user
  I want dependencies to be correctly tracked
  So my build is correct

  Background:
    Given a file named "proj/reggaefile.d" with:
      """
      import reggae;
      const mainObj = Target(`main.o`, `dmd -c -J$project/src -of$out $in`, [Target(`src/main.d`)], [Target(`src/string.txt`)]);
      const build = Build(Target(`leapp`, `dmd -of$out $in`, mainObj));
      """
    And a file named "proj/src/main.d" with:
      """
      import std.stdio;
      void main() {
          writeln(import(`string.txt`));
      }
      """
    And a file named "proj/src/string.txt" with:
      """
      Hello world!
      """


  Scenario: String import with make
    Given I run `reggae -b make proj`
    And the exit status should be 0
    When I run `make`
    Then the exit status should be 0
    When I run `./leapp`
    Then the output should contain:
      """
      Hello world!
      """
    Given I append to "proj/src/string.txt" with:
    """
    Goodbye!
    """
    When I run `make`
    And I run `./leapp`
    Then the output should contain:
      """
      Goodbye!
      """

  Scenario: String import with ninja
    Given I run `reggae -b ninja proj`
    And the exit status should be 0
    When I run `ninja`
    Then the exit status should be 0
    When I run `./leapp`
    Then the output should contain:
      """
      Hello world!
      """
    And the output should not contain:
      """
      Ninjas are people too
      """
    Given I append to "proj/src/string.txt" with:
      """
      Ninjas are people too

      """
    When I run `cat proj/src/string.txt`
    Then the output should contain:
      """
      Ninjas are people too
      """
    When I run `ninja`
    And I run `./leapp`
    Then the output should contain:
      """
      Ninjas are people too
      """
