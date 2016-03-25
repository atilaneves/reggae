Feature: Error messages
  As a user of Reggae
  I want to get meaningful error messages when I use the program incorrectly
  So I can accurately diagnose what went wrong

  Scenario: Non-existent directory
    When I run `reggae non/existent`
    Then it should fail with:
      """
      Could not find
      """

  Scenario: Non-existent build file
    Given an empty file named "path/to/foo.txt"
    When I run `reggae path/to`
    Then it should fail with:
      """
      Could not find
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
      mixin build!(Target(`foo`));
      mixin build!(Target(`bar`));
      """
    When I run `reggae humpty/dumpty/`
    Then it should fail with:
      """
      """

    Scenario: Too many languages
      Given a file named "project/reggaefile.d" with:
        """
        """
      And a file named "project/reggaefile.py" with:
        """
        """
      When I run `reggae -b ninja project`
      Then it should fail with:
        """
        Reggae builds may only use one language. Found: D, Python
        """
      Given a file named "project/reggaefile.rb" with:
        """
        """
      When I run `reggae -b ninja project`
      Then it should fail with:
        """
        Reggae builds may only use one language. Found: D, Python, Ruby
        """

      Given a file named "project/reggaefile.js" with:
        """
        """
      When I run `reggae -b ninja project`
      Then it should fail with:
        """
        Reggae builds may only use one language. Found: D, Python, Ruby, JavaScript
        """

      Given a file named "project/reggaefile.lua" with:
        """
        """
      When I run `reggae -b ninja project`
      Then it should fail with:
        """
        Reggae builds may only use one language. Found: D, Python, Ruby, JavaScript, Lua
        """
