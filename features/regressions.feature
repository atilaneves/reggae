@regression
Feature: Regressions
  As a reggae developer
  I want to reproduce bugs with regression tests
  So that bugs are not reintroduced

  @ninja
  Scenario: Github issue 10: dubConfigurationTarget doesn't work for unittest builds
    Given a file named "project/dub.json" with:
      """
      {
          "name": "dubproj",
          "configurations": [
              { "name": "executable"},
              { "name": "unittest"}
          ]
      }
      """
    And a file named "project/reggaefile.d" with:
      """
      import reggae;
      alias ut = dubConfigurationTarget!(ExeName(`ut`),
                                         Configuration(`unittest`),
                                         Flags(`-g -debug -cov`));
      mixin build!ut;
      """
    And a file named "project/source/src.d" with:
      """
      unittest { static assert(false, `oopsie`); }
      int add(int i, int j) { return i + j; }
      """
    And a file named "project/source/main.d" with:
      """
      import src;
      void main() {}
      """
    Given I successfully run `reggae -b ninja project`
    When I run `ninja`
    Then it should fail with:
      """
      oopsie
      """

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
