Feature: Static library
  As a reggae user
  I want to create static libraries easily
  So I don't have to type out explicit rules for them

  Background:
    Given a file named "project/reggaefile.d" with:
      """
      import reggae;
      alias lib = staticLibrary!(`maths.a`, Sources!([`libsrc`]));
      enum mainObj = objectFile(SourceFile(`src/main.d`));
      alias app = executable!(App(SourceFileName(`src/main.d`), BinaryFileName(`app`)),
                              Flags(),
                              ImportPaths([`libsrc`]),
                              StringImportPaths(),
                              lib);
      mixin build!app;
      """
    And a file named "project/libsrc/adder.d" with:
      """
      int add(int i, int j) { return i + j; }
      """
    And a file named "project/libsrc/muler.d" with:
      """
      int mul(int i, int j) { return i * j; }
      """
    And a file named "project/src/main.d" with:
      """
      import adder, muler;
      import std.stdio, std.conv;
      void main(string[] args) {
         immutable i = args[1].to!int;
         immutable j = args[2].to!int;
         writeln(`Adding      `, i, ` and `, j, `: `, add(i, j));
         writeln(`Multiplying `, i, ` and `, j, `: `, mul(i, j));
      }
      """

  @ninja
  Scenario: Ninja
    Given I successfully run `reggae -b ninja project`
    And I successfully run `ninja`
    When I successfully run `./app 2 3`
    Then the output should contain:
      """
      Adding      2 and 3: 5
      Multiplying 2 and 3: 6
      """
    And a file named "maths.a" should exist
