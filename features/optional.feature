Feature: Optional top-level targets
  As a reggae user
  I want some targets to be optional
  So that I build them only when I want to

  Background:
    Given a file named "proj/reggaefile.d" with:
      """
      import reggae;
      enum foo = Target(`foo`, `dmd -of$out $in`, Target(`foo.d`));
      enum bar = Target(`bar`, `dmd -of$out $in`, Target(`bar.d`));
      mixin build!(foo, optional(bar));
      """
    And a file named "proj/foo.d" with:
      """
      import std.stdio;
      void main() {
          writeln(`hello foo`);
      }
      """
    And a file named "proj/bar.d" with:
      """
      import std.stdio;
      void main() {
          writeln(`hello bar`);
      }
      """

  @ninja
  Scenario: Ninja
    Given I successfully run `reggae -b ninja proj`
    And I successfully run `ninja`
    When I successfully run `./foo`
    Then the output should contain:
      """
      hello foo
      """
    And the file "bar" should not exist
    Given I successfully run `ninja bar`
    When I successfully run `./bar`
    Then the output should contain:
      """
      hello bar
      """

  @make
  Scenario: Make
    Given I successfully run `reggae -b make proj`
    And I successfully run `make`
    When I successfully run `./foo`
    Then the output should contain:
      """
      hello foo
      """
    And the file "bar" should not exist
    Given I successfully run `make bar`
    When I successfully run `./bar`
    Then the output should contain:
      """
      hello bar
      """
