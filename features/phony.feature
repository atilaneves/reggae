Feature: Phony rules
  As a reggae user
  I want the build to perform tasks that don't have an output
  So that they're always built

  Background:
    Given a file named "proj/reggaefile.d" with:
      """
      import reggae;
      mixin build!(Target(`hello`, Command.phony(`echo helloooo`), []));
      """

  @make
  Scenario: Make
    Given I successfully run `reggae -b make proj`
    When I successfully run `make`
    Then the output should contain:
      """
      helloooo
      """
    Given I successfully run `touch hello`
    When I successfully run `make`
    Then the output should not contain:
      """
      make: Nothing to be done
      """

  @ninja
  Scenario: Ninja
    Given I successfully run `reggae -b ninja proj`
    When I successfully run `ninja`
    Then the output should contain:
      """
      helloooo
      """

  @binary
  Scenario: Binary
    Given I successfully run `reggae -b binary proj`
    When I successfully run `./build`
    Then the output should contain:
      """
      helloooo
      """
    Given I successfully run `touch hello`
    When I successfully run `./build`
    Then the output should not contain:
      """
      [build] Nothing to do
      """
