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

      unittest {
          assert(1 == 2);
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
      Given I successfully run `ninja ut`
      When I run `./ut`
      Then it should fail with:
      """
      oopsie
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

    Given I successfully run `reggae -b ninja --dflags="-g -debug" dub_proj`
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
    oopsie
    """
