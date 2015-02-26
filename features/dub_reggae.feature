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
          enc ~= cast(ubyte)adder(i, j);
          writeln(enc.bytes);
      }
      """

    And a file named "dub_reggae_proj/tests/util/ut_maths.d" with:
      """
      module tests.util.ut_maths;
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
      """

    And a file named "dub_reggae_proj/tests/util/more_maths.d" with:
      """
      module tests.util.more_maths;
      import util.maths;
      unittest {
          assert(adder(3, 4) == 7);
      }
      void testMoreAdder() {
          assert(adder(4, 9) == 13);
      }
      """

    And a file named "dub_reggae_proj/tests/ut.d" with:
      """
      import tests.util.ut_maths;
      import tests.util.more_maths;
      void main() {
          testAdd();
          testMul();
          testMoreAdder();
      }
      """

    And a file named "dub_reggae_proj/reggaefile.d" with:
      """
      import reggae;

      Build getBuild() {
          const utObjs = dObjects!(SrcDirs([`tests`]), Flags(`-unittest`), ImportPaths([`source`]));
          const ut = dLink(`ut`, utObjs ~ dubInfo.toTargets(No.main));
          return Build(dubInfo.target, ut);
      }
      """

    Scenario: Dub/Reggae build with Ninja
      Given I successfully run `reggae -b ninja dub_reggae_proj`
      When I successfully run `ninja`
      Then the output should not contain:
        """
        warning: multiple rules generate
        """
      When I successfully run `./ut`
      And I successfully run `./dub_reggae 2 3`
      Then the output should contain:
        """
        Sum:  5
        Prod: 6
        [5]
        """

    Scenario: Dub/Reggae build with Make
      Given I successfully run `reggae -b make dub_reggae_proj`
      When I successfully run `make -j8`
      Then the output should not contain:
        """
        warning: ignoring old recipe for target
        """
      When I successfully run `./ut`
      And I successfully run `./dub_reggae 3 4`
      Then the output should contain:
        """
        Sum:  7
        Prod: 12
        [7]
        """
