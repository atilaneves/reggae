@python
Feature: Default options
  As a reggae user
  I want to specify default option values in the build
  So I don't have to pass the same command-line arguments each time for a given project

  @ninja
  Scenario: Change C compiler
    Given a file named "reggaefile.py" with:
      """
      import reggae;
      defaultOptions.cCompiler = `weirdcc`;
      enum target = objectFile(SourceFile("foo.c"), Flags("-g -O0"), IncludePaths(["includey", "headers"]));
      """
