@python
Feature: Foreign language integration
  As a reggae user
  I want to be able to write build descriptions in a scripting language
  So I don't have to compile the build description

  Background:
    Given a file named "project/reggaefile.py" with:
      """
      from reggae import *
      app = scriptlike(src_name='src/main.d', exe_name='script', flags='-g')
      bld = Build(app)
      """

    And a file named "project/src/main.d" with:
      """
      import std.stdio;
      import std.conv;
      void main(string[] args) {
           writeln(args[1].to!int + args[2].to!int);
      }
      """

    @ninja
    Scenario: Ninja build with python
      Given I successfully run `reggae -b ninja project`
      And I successfully run `ninja`
      When I successfully run `./script 2 3`
      Then the output should contain:
        """
        5
        """
      When I successfully run `./script 4 3`
      Then the output should contain:
        """
        7
        """

    @make
    Scenario: Make build with python
      Given I successfully run `reggae -b make project`
      And I successfully run `make`
      When I successfully run `./script 2 3`
      Then the output should contain:
        """
        5
        """
      When I successfully run `./script 4 3`
      Then the output should contain:
        """
        7
        """

    @tup
    Scenario: Tup build with python
      Given I successfully run `reggae -b tup project`
      And I successfully run `tup`
      When I successfully run `./script 2 3`
      Then the output should contain:
        """
        5
        """
      When I successfully run `./script 4 3`
      Then the output should contain:
        """
        7
        """

    @binary
    Scenario: Binary build with python
      When I run `reggae -b binary project`
      Then it should fail with:
        """
        Binary backend not supported via JSON
        """

  @ninja
  Scenario: No exe_name
    Given a file named "project/reggaefile.py" with:
      """
      from reggae import *
      app = scriptlike(src_name='src/script.d', flags='-g')
      bld = Build(app)
      """

    And a file named "project/src/script.d" with:
      """
      import std.stdio;
      import std.conv;
      void main(string[] args) {
           writeln(args[1].to!int + args[2].to!int);
      }
      """

    Given I successfully run `reggae -b ninja project`
    And I successfully run `ninja`
    When I successfully run `./script 2 3`
    Then the output should contain:
      """
      5
      """
    When I successfully run `./script 4 3`
    Then the output should contain:
      """
      7
      """
