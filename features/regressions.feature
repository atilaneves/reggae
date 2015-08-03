@regression
Feature: Regressions
  As a reggae developer
  I want to reproduce bugs with regression tests
  So that bugs are not reintroduced

  @ninja
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
