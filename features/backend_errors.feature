Feature: Backend errors
  As a user of Reggae
  I want to be notified of errors regarding backend specification
  So that I can easily diagnose the error

  Background:
    Given a file named "lvl1/lvl2/reggaefile.d" with:
      """
      import reggae;
      mixin build!(Target(`foo`));
      """

  Scenario: No backend specified
    When I run `reggae lvl1/lvl2/`
    Then it should fail with:
      """
      A backend must be specified with -b/--backend
      """

  Scenario: Option used but no backend specified
    When I run `reggae -b lvl1/lvl2`
    Then it should fail with:
      """
      Unsupported backend, -b must be one of: make|ninja|tup|binary
      """

  Scenario: Non-existent option used
    When I run `reggae -b foo lvl1/lvl2`
    Then it should fail with:
      """
      Unsupported backend, -b must be one of: make|ninja|tup|binary
      """
