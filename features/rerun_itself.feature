Feature: Re-run reggae when dependencies deem it necessary
  As a user of reggae
  I want it to keep track of when it needs to regenerate the build
  So I don't have to

  Background:
    Given a file named "proj/src/main.d" with:
      """
      import func;
      void main() { myfunc(); }
      """
    And a file named "proj/src/func.d" with:
      """
      module func;
      import std.stdio;
      void myfunc() { writeln(`Mainymainy`); }
      """
    And a file named "proj/src/other.d" with:
      """
      module func;
      import std.stdio;
      void myfunc() { writeln(`Lookee me!`); }
      """

    And a file named "proj/reggaefile.d" with:
      """
      import reggae;
      import reggaebuild.defs; //for funcObj
      enum mainObj = Target(`main.o`,
                             `dmd -I$project/src -c $in -of$out`,
                             Target(`src/main.d`));
      enum app = Target(`myapp`,
                         `dmd -of$out $in`,
                         [mainObj, funcObj],
                         );
      mixin build!(app);
      """
    And a file named "proj/reggaebuild/defs.d" with:
      """
      module reggaebuild.defs;
      import reggae;
      enum funcObj = Target(`func.o`,
                             `dmd -I$project/src -c $in -of$out`,
                             Target(`src/func.d`));
      """

    @ninja
    Scenario: D Rerun with Ninja
      Given I successfully run `reggae -b ninja proj`
      And I successfully run `ninja`
      When I successfully run `./myapp`
      Then the output should contain:
        """
        Mainymainy
        """
      And the output should not contain:
        """
        Lookee me!
        """

      Given I successfully run `sleep 1` for up to 2 seconds
      And I overwrite "proj/reggaebuild/defs.d" with:
        """
        module reggaebuild.defs;
        import reggae;
        enum funcObj = Target(`other.o`,
                              `dmd -I$project/src -c $in -of$out`,
                              Target(`src/other.d`));
        """

      When I successfully run `ninja`
      And I successfully run `./myapp`
      Then the output should contain:
        """
        Lookee me!
        """
      Given I successfully run `ninja -t clean`
      Then I successfully run `ninja`


    @make
    Scenario: D Rerun with Make
      Given I successfully run `reggae -b make proj`
      And I successfully run `make`
      When I successfully run `./myapp`
      Then the output should contain:
        """
        Mainymainy
        """
      And the output should not contain:
        """
        Lookee me!
        """

      Given I successfully run `sleep 1` for up to 2 seconds
      And I overwrite "proj/reggaebuild/defs.d" with:
        """
        module reggaebuild.defs;
        import reggae;
        enum funcObj = Target(`other.o`,
                                `dmd -I$project/src -c $in -of$out`,
                                Target(`src/other.d`));
        """

      When I successfully run `make`
      And I successfully run `./myapp`
      Then the output should contain:
        """
        Lookee me!
        """

    @binary
    Scenario: D Rerun with Binary
      Given I successfully run `reggae -b binary proj`
      And I successfully run `./build`
      When I successfully run `./myapp`
      Then the output should contain:
        """
        Mainymainy
        """
      And the output should not contain:
        """
        Lookee me!
        """

      Given I successfully run `sleep 1` for up to 2 seconds
      And I overwrite "proj/reggaebuild/defs.d" with:
        """
        module reggaebuild.defs;
        import reggae;
        enum funcObj = Target(`other.o`,
                                `dmd -I$project/src -c $in -of$out`,
                                Target(`src/other.d`));
        """

      When I successfully run `./build`
      And I successfully run `./myapp`
      Then the output should contain:
        """
        Lookee me!
        """
