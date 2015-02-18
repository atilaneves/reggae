Feature: Error messages
  As a user of Reggae
  I want to get meaningful error messages when I use the program incorrectly
  So I can accurately diagnose what went wrong

  Scenario: Directory not specified
    When I run `reggae`
    Then it should fail with:
      """
      A project path must be specified
      """

  Scenario: Non-existent directory
    When I run `reggae non/existent`
    Then it should fail with:
      """
      Could not find non/existent/reggaefile.d
      """

  Scenario: Non-existent build file
    Given an empty file named "path/to/foo.txt"
    When I run `reggae path/to`
    Then it should fail with:
      """
      Could not find path/to/reggaefile.d
      """

  Scenario: Empty build file
    Given an empty file named "here/is/my/proj/reggaefile.d"
    When I run `reggae here/is/my/proj`
    Then it should fail with:
      """
      Could not find a public Build object in reggaefile
      """

  Scenario: Too many build objects
    Given a file named "humpty/dumpty/reggaefile.d" with:
      """
      import reggae;
      const build1 = build(Target(`foo`));
      const build2 = build(Target(`bar`));
      """
    When I run `reggae humpty/dumpty/`
    Then it should fail with:
      """
      Only one build object allowed per module, reggaefile has 2
      """
