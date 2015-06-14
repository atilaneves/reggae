@binary
Feature: Binary backend
  As a reggae user
  I want to be able to have a binary backend
  So that I don't depend on external programs for building

  Background:
    Given a file named "proj/reggaefile.d" with:
    """
    import reggae;
    mixin build!(Target(`copy.txt`,`cp $project/original.txt copy.txt`, Target(`original.txt`)));
    """

    And a file named "proj/original.txt" with:
      """
      See the little goblin
      See his little feet
      And his little nosey-wose
      Isn't the goblin sweet?
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
