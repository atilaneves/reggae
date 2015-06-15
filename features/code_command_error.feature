Feature: D code as a target command
  As a reggae user
  I want to be able to specify D code instead of a shell command
  So I can do complicated D build

  Background: Non-binary builds
    Given a file named "proj/reggaefile.d" with:
      """
      import reggae;
      import std.stdio;
      void func(in string[], in string[]) { writeln(`func was called`); }
      mixin build!(Target(`copy.txt`, &func, Target(`original.txt`)));
      """

  @ninja
  Scenario: Ninja
    When I run `reggae -b ninja proj`
    Then it should fail with:
      """
      Command type 'code' not supported for ninja backend
      """

  @make
  Scenario: Make
    When I run `reggae -b make proj`
    Then it should fail with:
      """
      Command type 'code' not supported for make backend
      """

  @tup
  Scenario: Tup
    When I run `reggae -b tup proj`
    Then it should fail with:
      """
      Command type 'code' not supported for tup backend
      """
