Feature: D code as a target command
  As a reggae user
  I want to be able to specify D code instead of a shell command
  So I can do complicated D builds

  Scenario: Printing instead of compiling
    Given a file named "proj/reggaefile.d" with:
      """
      import reggae;
      import std.stdio;
      void func() { writeln(`func was called`); }
      mixin build!(Target(`copy.txt`, &func, Target(`original.txt`)));
      """

    And I successfully run `reggae -b binary proj`
    When I run `./build`
    Then the output should contain:
      """
      func was called
      """
