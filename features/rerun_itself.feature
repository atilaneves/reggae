Feature: Re-run reggae when dependencies deem it necessary
  As a user of reggae
  I want it to keep track of when it needs to regenerate the build
  So I don't have to

  Background:
    Given a file named "proj/src/main.d" with:
      """
      import std.stdio;
      void main() { writeln(`Mainymainy`);}
      """
    And a file named "proj/src/other.d" with:
      """
      import std.stdio;
      void myfunc() { writeln(`Lookee me!`);}
      """
    And a file named "proj/reggaefile.d" with:
      """
      import reggae;
      const mainObj  = Target(`main.o`,  `dmd -I$project/src -c $in -of$out`, Target(`src/main.d`));
      const app = Target(`myapp`,
                         `dmd -of$out $in`,
                         [mainObj],
                         );
      mixin build!(app);
      """

    Scenario: Rerun with Ninja
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

      Given I overwrite "proj/reggaefile.d" with:
        """
        import reggae;
        const mainObj  = Target(`main.o`,  `dmd -I$project/src -c $in -of$out`, Target(`src/main.d`));
        const otherObj = Target(`other.o`, `dmd -I$project/src -c $in -of$out`, Target(`src/other.d`));
        const app = Target(`myapp`,
                         `dmd -of$out $in`,
                         [mainObj, otherObj],
                         );
        mixin build!(app);
        """
      And I overwrite "proj/src/main.d" with:
        """
        import other;
        void main() { myfunc();}
        """

      When I successfully run `ninja`
      And I successfully run `./myapp`
      Then the output should contain:
        """
        Lookee me!
        """
