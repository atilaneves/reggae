Feature: Outputs in the project path
  As a reggae user
  I want to create outputs in the project path
  So I can have control over where they're generated

  Background:
    Given a file named "proj/reggaefile.d" with:
      """
      import reggae;
      enum copy = Target(`$project/generated/release/64/linux/copy.txt`, `cp $in $out`, [Target(`foo.txt`)]);
      mixin build!copy;
      """
    And a file named "proj/foo.txt" with:
      """
      In the middle of the night
      I was walking down the street

      """

    @ninja
    Scenario: Ninja
      Given I successfully run `reggae -b ninja proj`
      When I successfully run `ninja`
      Then a file named "proj/generated/release/64/linux/copy.txt" should exist

    @make
    Scenario: Make
      Given I successfully run `reggae -b make proj`
      When I successfully run `make`
      Then a file named "proj/generated/release/64/linux/copy.txt" should exist

    # The command succeeds but tup thinks it didn't
    # @tup
    # Scenario: Tup
    #   Given I successfully run `reggae -b tup proj`
    #   When I successfully run `tup`
    #   Then a file named "proj/generated/release/64/linux/copy.txt" should exist

    @binary
    Scenario: binary
      Given I successfully run `reggae -b binary proj`
      When I successfully run `./build`
      Then a file named "proj/generated/release/64/linux/copy.txt" should exist
