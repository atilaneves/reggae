@lua
Feature: Foreign language integration
  As a reggae user
  I want to be able to write build descriptions in lua
  So I don't have to compile the build description

  Background:
    Given a file named "path/to/reggaefile.lua" with:
      """
      local reggae = require('reggae')
      local mainObj = reggae.Target('main.o', 'dmd -I$project/src -c $in -of$out', reggae.Target('src/main.d'))
      local mathsObj = reggae.Target('maths.o', 'dmd -c $in -of$out', reggae.Target('src/maths.d'))
      local app = reggae.Target('myapp', 'dmd -of$out $in', {mainObj, mathsObj})
      local bld = reggae.Build(app)
      return {bld = bld}
      """
    And a file named "path/to/src/main.d" with:
      """
      import maths;
      import std.stdio;
      import std.conv;
      void main(string[] args) {
          const a = args[1].to!int;
          const b = args[2].to!int;
          writeln(`The sum     of `, a, ` and `, b, ` is `, adder(a, b));
          writeln(`The product of `, a, ` and `, b, ` is `, prodder(a, b));
      }
      """
    And a file named "path/to/src/maths.d" with:
      """
      int adder(int a, int b) { return a + b; }
      int prodder(int a, int b) { return a * b; }
      """

    @ninja
    Scenario: Ninja build with lua
      Given I successfully run `reggae -b ninja path/to`
      And I successfully run `ninja`
      When I successfully run `./myapp 2 3`
      Then the output should contain:
        """
        The sum     of 2 and 3 is 5
        The product of 2 and 3 is 6
        """
      When I run `./myapp 3 4`
      Then the output should contain:
        """
        The sum     of 3 and 4 is 7
        The product of 3 and 4 is 12
        """

    @make
    Scenario: Make build with lua
      Given I successfully run `reggae -b make path/to`
      And I successfully run `make`
      When I successfully run `./myapp 2 3`
      Then the output should contain:
        """
        The sum     of 2 and 3 is 5
        The product of 2 and 3 is 6
        """
      When I run `./myapp 3 4`
      Then the output should contain:
        """
        The sum     of 3 and 4 is 7
        The product of 3 and 4 is 12
        """

    @tup
    Scenario: Tup build with lua
      Given I successfully run `reggae -b tup path/to`
      And I successfully run `tup`
      When I successfully run `./myapp 2 3`
      Then the output should contain:
        """
        The sum     of 2 and 3 is 5
        The product of 2 and 3 is 6
        """
      When I run `./myapp 3 4`
      Then the output should contain:
        """
        The sum     of 3 and 4 is 7
        The product of 3 and 4 is 12
        """

    @binary
    Scenario: Binary build with lua
      When I run `reggae -b binary path/to`
      Then it should fail with:
        """
        Binary backend not supported via JSON
        """
