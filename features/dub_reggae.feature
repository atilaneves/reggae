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
      import std.process;
      import std.exception;
      import std.conv;

      Build getBuild() {
          auto ut = dCompile(`tests/ut_maths.d`, ``, [`source`]);
          return Build(dLink(`ut`, dubInfo.toTargets(No.main) ~ ut));
      }
      """

    Scenario: Dub/Reggae build with Ninja
      When I successfully run `reggae -b ninja dub_reggae_proj`
      Given I successfully run `ninja`
      When I successfully run `./ut`
