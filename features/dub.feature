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
        "dflags": ["-g", "-debug"],
        "importPaths": ["imps"],
        "stringImportPaths": "stringies",
        "dependencies": {"cerealed": ">=0.5.2"}
      }
      """

    And a file named "source/main.d" with:
      """
      import strings;
      import cerealed;
      import std.stdio;
      void main(string[] args) {
          writeln(import(`banner.txt``));
          auto enc = Cereal();
          enc ~= 4;
          writeln(enc.bytes);
          writeln(string1);
      }
      """

    And a file named "stringies/banner.txt" with:
      """
      Why hello!
      """

    And a file named "imps/strings.d" with:
      """
      immutable string1 = `I'm immortal!`;
      """

    Scenario: Dub/Reggae build with Ninja
      Given I successfully run `reggae -b ninja dub_proj`
      When I successfully run `ninja -v`
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
