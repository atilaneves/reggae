Feature: Running the binary on a D build description results in a working build
  As a reggae user
  I want to write build descriptions in D
  So I can build software easily

  Background:
    Given a file named "proj/reggaefile.d" with:
      """
      import reggae;
      enum mainObj = Target(`main.o`,
                            `dmd -c -of$out $in`,
                            [Target(`src/main.d`)]);
      mixin build!(Target(`leapp`, `dmd -of$out $in`, mainObj));
      """
    And a file named "proj/src/main.d" with:
      """
      import std.stdio;
      void main() {
          writeln(`Hello world!`);
      }
      """

  @ninja
  Scenario: End to end with ninja
    Given I successfully run `reggae -b ninja proj`
    And I successfully run `ninja`
    When I successfully run `./leapp`
    Then the output should contain:
      """
      Hello world!
      """

  @make
  Scenario: End to end with make
    Given I successfully run `reggae -b make proj`
    And I successfully run `make`
    When I successfully run `./leapp`
    Then the output should contain:
      """
      Hello world!
      """

  @tup
  Scenario: End to end with tup
    Given I successfully run `reggae -b tup proj`
    And I successfully run `tup`
    When I successfully run `./leapp`
    Then the output should contain:
      """
      Hello world!
      """

  @binary
  Scenario: End to end with binary
    Given I successfully run `reggae -b binary proj`
    Given I successfully run `./build`
    Then the output should contain:
    """
    [build] dmd -ofleapp objs/leapp.objs/main.o
    """
    When I successfully run `./leapp`
    Then the output should contain:
      """
      Hello world!
      """
