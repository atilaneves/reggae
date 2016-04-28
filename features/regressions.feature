@regression
Feature: Regressions
  As a reggae developer
  I want to reproduce bugs with regression tests
  So that bugs are not reintroduced

  @ninja
  Scenario: Using . as the project should work
    Given a file named "reggaefile.d" with:
    """
    import reggae;
    mixin build!(scriptlike!(App(SourceFileName(`app.d`))));
    """
    And a file named "app.d" with:
    """
    import std.stdio;
    void main() { writeln(`Hello world!`); }
    """
    When I successfully run `reggae -b ninja .`
    And I successfully run `ninja`
    And I successfully run `./app`
    Then the output should contain:
    """
    Hello world!
    """
