Feature: D code as a target command
  As a reggae user
  I want to be able to specify D code instead of a shell command
  So I can do complicated D builds

  Scenario: Printing instead of compiling
    Given a file named "proj/reggaefile.d" with:
      """
      import reggae;
      import std.stdio;
      void func(in string[], in string[]) { writeln(`func was called`); }
      mixin build!(Target(`copy.txt`, &func, Target(`original.txt`)));
      """

    And I successfully run `reggae -b binary proj`
    When I run `./build`
    Then the output should contain:
      """
      func was called
      """

  Scenario: Generation of outputs
    Given a file named "proj/reggaefile.d" with:
      """
      import reggae;
      import std.process;
      import std.exception;
      import std.array;
      void func(in string[] inputs, in string[] outputs) {
          immutable cmd = [`cp`, inputs[0], outputs[0]];
          immutable res = execute(cmd);
          enforce(res.status == 0, `Could not execute ` ~ cmd.join(` `) ~ `\n` ~ res.output);
      }
      mixin build!(Target(`copy.txt`, &func, Target(`original.txt`)));
      """

    And a file named "proj/original.txt" with:
      """
      Originalis
      """

    When I successfully run `reggae -b binary proj`
    And I run `./build`
    And I run `cat copy.txt`
    Then the output should contain:
      """
      Originalis
      """
