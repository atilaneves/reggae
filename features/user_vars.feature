Feature: User-defined variables
  As a user of reggae
  I want to be able to define my own build-time variables
  So that the build system is configurable

  Background:
    Given a file named "dub_reggae_proj/dub.json" with:
      """
      {
        "name": "var_app",
        "target_type": "executable",
        "dependencies": {"cerealed": ">=0.5.2"}
      }
      """

    And a file named "dub_reggae_proj/source/doit.d" with:
      """
      import cerealed;
      struct MyStruct { int i;}
      const(ubyte)[] numberise(in MyStruct s) {
          auto enc = Cerealiser();
          enc ~= s;
          return enc.bytes;
      }
      """

    And a file named "dub_reggae_proj/source/main.d" with:
      """
      import std.stdio;
      import std.conv;
      import doit;
      void main(string[] args) {
          immutable i = args[1].to!int;
          writeln(`Numberisation: `, numberise(MyStruct(i)));
      }
      """

    And a file named "dub_reggae_proj/tests/ut.d" with:
      """
      import doit;
      unittest {
          assert(numberise(MyStruct(5)) == [0, 0, 0, 5]);
      }
      """

    And a file named "dub_reggae_proj/reggaefile.d" with:
      """
      import reggae;
      alias utObjs = objectFiles!(Sources!([`tests`]),
                                  Flags(`-unittest -main`),
                                  ImportPaths(configToDubInfo[`default`].mainTargetImportPaths() ~
                                              `source`));
      alias ut = dubConfigurationTarget!(ExeName(`ut`), Configuration(), Flags(), No.main, utObjs);
      static if(userVars.get(`noUnitTests`, false)) {
          mixin build!(dubDefaultTarget!());
      } else {
          mixin build!(dubDefaultTarget!(), ut);
      }
      """

    @ninja
    Scenario: User-defined variabled with Ninja
      Given I successfully run `reggae -b ninja -d noUnitTests=true dub_reggae_proj`
      When I successfully run `ninja`
      And I successfully run `./var_app 3`
      Then the output should contain:
        """
        Numberisation: [0, 0, 0, 3]
        """
      And a file named "ut" should not exist

      Given I successfully run `reggae -b ninja -d noUnitTests=false dub_reggae_proj`
      When I successfully run `ninja`
      And I successfully run `./var_app 3`
      Then the output should contain:
        """
        Numberisation: [0, 0, 0, 3]
        """
      When I successfully run `./ut`

    @make
    Scenario: User-defined variabled with Make
      Given I successfully run `reggae -b make -d noUnitTests=true dub_reggae_proj`
      When I successfully run `make`
      And I successfully run `./var_app 3`
      Then the output should contain:
        """
        Numberisation: [0, 0, 0, 3]
        """
      And a file named "ut" should not exist

      Given I successfully run `reggae -b make -d noUnitTests=false dub_reggae_proj`
      When I successfully run `make`
      And I successfully run `./var_app 3`
      Then the output should contain:
        """
        Numberisation: [0, 0, 0, 3]
        """
      When I successfully run `./ut`

    @binary
    Scenario: User-defined variabled with Binary
      Given I successfully run `reggae -b binary -d noUnitTests=true dub_reggae_proj`
      When I successfully run `./build`
      And I successfully run `./var_app 3`
      Then the output should contain:
        """
        Numberisation: [0, 0, 0, 3]
        """
      And a file named "ut" should not exist

      Given I successfully run `reggae -b binary -d noUnitTests=false dub_reggae_proj`
      When I successfully run `./build`
      And I successfully run `./var_app 3`
      Then the output should contain:
        """
        Numberisation: [0, 0, 0, 3]
        """
      When I successfully run `./ut`
