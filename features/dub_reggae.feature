Feature: Augmenting dub projects with reggae builds
  As a user of both dub and reggae
  I want to base my reggae builds from the dub information
  So I don't have to duplicate work

  Background:
    Given a file named "dub_reggae_proj/dub.json" with:
      """
      {
        "name": "dub_reggae",
        "targetType": "executable",
        "dependencies": {"cerealed": ">=0.5.2"}
      }

      """

    And a file named "dub_reggae_proj/source/util/maths.d" with:
      """
      module util.maths;
      int adder(int i, int j) {
          return i + j;
      }

      int muler(int i, int j) {
          return i * j;
      }
      """

    And a file named "dub_reggae_proj/source/main.d" with:
      """
      import util.maths;
      import cerealed;
      import std.stdio;
      import std.conv;
      void main(string[] args) {
          immutable i = args[1].to!int;
          immutable j = args[2].to!int;
          writeln(`Sum:  `, adder(i, j));
          writeln(`Prod: `, muler(i, j));
          auto enc = Cerealiser();
          enc ~= cast(ubyte)3;
          writeln(enc.bytes);
      }
      """

    And a file named "dub_reggae_proj/tests/ut_maths.d" with:
      """
      import util.maths;
      void testAdd() {
          assert(adder(3, 0) == 3);
          assert(adder(3, 2) == 5);
      }

      void testMul() {
          assert(muler(3, 0) == 0);
          assert(muler(3, 1) == 3);
          assert(muler(3, 4) == 12);
      }

      void main() {
          testAdd();
          testMul();
      }
      """

    And a file named "dub_reggae_proj/reggaefile.d" with:
      """
      import reggae;
      import reggae.dub_json;
      import std.process;
      import std.exception;
      import std.conv;

      Build getBuild() {
          const string[string] env = null;
          Config config = Config.none;
          size_t maxOutput = size_t.max;
          immutable workDir = projectPath;
          immutable dubArgs = [`dub`, `describe`];

          auto ret = execute(dubArgs);
          enforce(ret.status == 0, text(`Could not execute `, dubArgs, `\n`, ret.output));

          auto info = dubInfo(ret.output);
          auto ut = dCompile(`tests/ut_maths.d`);
          return Build(dLink(`ut`, info.toTargets ~ ut));
      }
      """

    Scenario: Dub/Reggae build with Ninja
      When I successfully run `reggae -b ninja dub_reggae_proj`
      Given I successfully run `ninja`
      When I successfully run `./ut`
