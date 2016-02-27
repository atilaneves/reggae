Feature: Dub integration
  As a user of both dub and reggae
  I want to import the dub targets into the reggae description
  So that I can build my dub projects with reggae

  Background:
    Given a file named "dub_proj/dub.json" with:
      """
      {
        "name": "atest",
        "targetType": "executable",
        "importPaths": ["imps"],
        "stringImportPaths": ["stringies"],
        "dependencies": {"cerealed": "~>0.6.3"}
      }

      """

    And a file named "dub_proj/source/main.d" with:
      """
      import strings;
      import cerealed;
      import std.stdio;
      void main(string[] args) {
          writeln(import(`banner.txt`));
          auto enc = Cerealiser();
          enc ~= 4;
          writeln(enc.bytes);
          writeln(string1);
      }
      """

    And a file named "dub_proj/stringies/banner.txt" with:
      """
      Why hello!
      """

    And a file named "dub_proj/imps/strings.d" with:
      """
      enum string1 = `I'm immortal!`;
      """

    @ninja
    Scenario: Dub/Reggae build with Ninja
      When I successfully run `reggae -b ninja --dflags="-g -debug" dub_proj`
      Then the file "dub_proj/reggaefile.d" should not exist
      And a file named "reggaefile.d" should exist
      When I successfully run `ninja`
      Then the output should contain:
        """
        -g -debug
        """
      When I successfully run `./atest`
      Then the output should contain:
        """
        Why hello!
        [0, 0, 0, 4]
        I'm immortal!
        """

    @make
    Scenario: Dub/Reggae build with Make
      When I successfully run `reggae -b make dub_proj --dflags="-g -debug"`
      Then the file "dub_proj/reggaefile.d" should not exist
      And a file named "reggaefile.d" should exist
      When I successfully run `make -j8`
      Then the output should contain:
        """
        -g -debug
        """
      When I successfully run `./atest`
      Then the output should contain:
        """
        Why hello!
        [0, 0, 0, 4]
        I'm immortal!
        """

    @binary
    Scenario: Dub/Reggae build with Binary
      When I successfully run `reggae -b binary dub_proj --dflags="-g -debug"`
      Then the file "dub_proj/reggaefile.d" should not exist
      And a file named "reggaefile.d" should exist
      When I successfully run `./build`
      Then the output should contain:
        """
        -g -debug
        """
      When I successfully run `./atest`
      Then the output should contain:
        """
        Why hello!
        [0, 0, 0, 4]
        I'm immortal!
        """

    @tup
    Scenario: Dub/Reggae build with Tup
      When I run `reggae -b tup dub_proj`
      Then it should fail with:
        """
        dub integration not supported with the tup backend
        """

  @ninja
  Scenario: Automatic unit test binary with no unittest configuration
    Given a file named "dub_proj/dub.json" with:
      """
      {
        "name": "atest",
        "targetType": "executable",
      }

      """

    And a file named "dub_proj/source/main.d" with:
      """
      import std.stdio;
      void main(string[] args) {
          writeln(`1st arg: `, args[1]);
      }

      unittest {
          assert(1 == 2, `oopsie`);
      }
      """

    Given I successfully run `reggae -b ninja dub_proj`
    And I successfully run `ninja`
    When I successfully run `./atest foo`
    Then the output should contain:
      """
      1st arg: foo
      """
    Given I successfully run `ninja ut`
    When I run `./ut foo`
    Then it should fail with:
    """
    oopsie
    """

  @ninja
  Scenario: Automatic unit test binary with no unittest configuration
    Given a file named "dub_ut_proj/dub.json" with:
      """
      {
        "name": "atest",
        "targetType": "executable",
        "configurations": [
          { "name": "executable"},
          { "name": "unittest",
            "mainSourceFile": "tests/ut.d",
            "excludedSourceFiles": ["source/main.d"]
          }
        ]
      }

      """

    And a file named "dub_ut_proj/source/main.d" with:
      """
      import std.stdio;
      void main(string[] args) {
          writeln(`1st arg: `, args[1]);
      }

      unittest {
          assert(1 == 2, `oopsie`);
      }
      """
    And a file named "dub_ut_proj/tests/ut.d" with:
      """
      import std.stdio;
      void main() {
          writeln("This is the UT binary");
      }
      unittest {
          assert(1 == 2, `ut no good`);
      }
      """

    Given I successfully run `reggae -b ninja dub_ut_proj`
    And I successfully run `ninja`
    When I successfully run `./atest foo`
    Then the output should contain:
      """
      1st arg: foo
      """
    Given I successfully run `ninja ut`
    When I run `./ut`
    Then it should fail with:
    """
    ut no good
    """

  @ninja
  Scenario: dub project with preBuildCommands
    Given a file named "dub_prebuild/dub.json" with:
      """
      {
        "name": "prebuild",
        "targetType": "executable",
        "configurations": [
          { "name": "executable" },
          { "name": "unittest",
            "preBuildCommands": ["dub run unit-threaded -c gen_ut_main -- -f ut.d"],
            "mainSourceFile": "ut.d",
            "excludedSourceFiles": ["source/main.d"],
            "dependencies": {
              "unit-threaded": "~>0.6.0"
            }
          }
        ]
      }
      """
    And a file named "dub_prebuild/source/main.d" with:
      """
      import std.stdio, std.conv;;
      import maths;
      void main(string[] args) {
         writeln(`Result: `, mul(args[1].to!int, 2));
      }
      """
    And a file named "dub_prebuild/source/maths.d" with:
      """
      int mul(int i, int j) { return i * j; }
      unittest { assert(mul(2, 3) == 5); }
      unittest { assert(mul(3, 4) == 12); }
      """
    When I successfully run `reggae -b ninja dub_prebuild`
    And I successfully run `ninja prebuild`
    And I successfully run `./prebuild 3`
    Then the output should contain:
      """
      Result: 6
      """

    Given I successfully run `ninja ut`
    When I run `./ut`
    Then it should fail with:
       """
       2 test(s) run, 1 failed.
       """
