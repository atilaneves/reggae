@binary
Feature: Binary backend
  As a reggae user
  I want to be able to have a binary backend
  So that I don't depend on external programs for building

  Background:
    Given a file named "proj/reggaefile.d" with:
    """
    import reggae;
    mixin build!(Target(`copy.txt`,`cp $project/original.txt copy.txt`, Target(`original.txt`)),
                 Target(`foo`, `dmd -of$out $in`, Target(`foo.d`)));
    """

    And a file named "proj/original.txt" with:
      """
      See the little goblin
      See his little feet
      And his little nosey-wose
      Isn't the goblin sweet?

      """

    And a file named "proj/foo.d" with:
      """
      import std.stdio;
      void main() { writeln(`foobar`); }
      """

  Scenario: Do nothing after build
    Given I successfully run `reggae -b binary proj`
    And I successfully run `./build`
    When I successfully run `cat copy.txt`
    Then the output should contain:
      """
      See the little goblin
      See his little feet
      And his little nosey-wose
      Isn't the goblin sweet?
      """

    When I run `./build`
    Then the output should contain:
      """
      [build] Nothing to do
      """

  Scenario: Selectively build targets
    Given I successfully run `reggae -b binary proj`
    And I successfully run `./build foo`
    When I run `cat copy.txt`
    Then it should fail with:
      """
      """
    When I successfully run `./foo`
    Then the output should contain:
      """
      foobar
      """

    When I successfully run `./build`
    And I successfully run `cat copy.txt`
    Then the output should contain:
      """
      See the little goblin
      See his little feet
      And his little nosey-wose
      Isn't the goblin sweet?
      """

  Scenario: Listing targets
    Given I successfully run `reggae -b binary proj`
    And I successfully run `./build -l`
    Then the output should contain:
      """
      List of available top-level targets:
      - copy.txt
      - foo
      """
