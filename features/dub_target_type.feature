Feature: Dub arget type
  As a user of reggae
  I want to have an error message when using it on unsupported project types
  So I can diagnose what's going on

  Scenario: None target type
    Given a file named "proj/dub.json" with:
      """
      {
        "name": "notargettype",
        "license": "MIT",
        "targetType": "none"
      }
      """
    When I run `reggae -b ninja proj`
    Then it should fail with:
      """
      Unsupported dub targetType 'none'
      """
