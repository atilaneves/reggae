@regression
Feature: Regressions
  As a reggae developer
  I want to reproduce bugs with regression tests
  So that bugs are not reintroduced

  @ninja @autofail
  Scenario: Recursive dub dependencies
    Given a file named "project/dub.json" with:
      """
      {
          "targetType": "executable",
          "name": "simpleshader",
          "mainSourceFile": "simpleshader.d",

          "dependencies":
          {
              "gfm:sdl2": "*",
              "gfm:opengl": "*",
              "gfm:logger": "*"
          }
      }
      """
    And a file named "project/simpleshader.d" with:
      """
      import std.math, std.random, std.typecons;
      import std.experimental.logger;
      import derelict.util.loader;
      import gfm.logger, gfm.sdl2, gfm.opengl, gfm.math;
      void main() {}
      """
    When I successfully run `reggae -b ninja project`
    And I successfully run `ninja`

    @ninja
    Scenario: Github issue 14: $builddir not expanded
      Given a file named "project/reggaefile.d" with:
        """
        import reggae;

        const ao = objectFile(SourceFile("a.c"));
        const liba = Target("$builddir/liba.a", "ar rcs $out $in", [ao]);
        mixin build!(liba);
        """
      And a file named "project/a.c" with:
        """
        """
      When I successfully run `reggae -b ninja project`
      Then I successfully run `ninja`

    @ninja
    Scenario: Github issue 12: Can't set executable as a dependency
      Given a file named "project/reggaefile.d" with:
        """
        import reggae;
        alias app = executable!(App(SourceFileName("src/main.d"), BinaryFileName("$builddir/myapp")),
                                Flags("-g -debug"),
                                ImportPaths(["/path/to/imports"])
                                );
        alias code_gen = target!("out.c", "./myapp $in $out", target!"in.txt", app);
        mixin build!(code_gen);
        """
      And a file named "project/src/main.d" with:
        """
        import std.stdio;
        import std.algorithm;
        import std.conv;
        void main(string[] args) {
            const inFileName = args[1];
            const outFileName = args[2];
            auto lines = File(inFileName).byLine.
                                          map!(a => a.to!string).
                                          map!(a => a ~ ` ` ~ a);
            auto outFile = File(outFileName, `w`);
            foreach(line; lines) outFile.writeln(line);
        }
        """
      And a file named "project/in.txt" with:
        """
        foo
        bar
        baz
        """
      When I successfully run `reggae -b ninja project`
      And I successfully run `ninja`
      And I successfully run `cat out.c`
      Then the output should contain:
       """
       foo foo
       bar bar
       baz baz
       """

    @ninja
    Scenario: Github issue 10: dubConfigurationTarget doesn't work for unittest builds
      Given a file named "project/dub.json" with:
        """
        {
            "name": "dubproj",
            "configurations": [
                { "name": "executable"},
                { "name": "unittest"}
            ]
        }
        """
      And a file named "project/reggaefile.d" with:
        """
        import reggae;
        alias ut = dubConfigurationTarget!(ExeName(`ut`),
                                           Configuration(`unittest`),
                                           Flags(`-g -debug -cov`));
        mixin build!ut;
        """
      And a file named "project/source/src.d" with:
        """
        unittest { static assert(false, `oopsie`); }
        int add(int i, int j) { return i + j; }
        """
      And a file named "project/source/main.d" with:
        """
        import src;
        void main() {}
        """
      Given I successfully run `reggae -b ninja project`
      When I run `ninja`
      Then it should fail with:
        """
        oopsie
        """
