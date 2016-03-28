@python
Feature: Foreign language integration
  As a reggae user
  I want to be able to write build descriptions in a scripting language
  So I don't have to compile the build description

  Background:
    Given a file named "project/src/main.cpp" with:
    """
    #include <iostream>
    extern int twice(int i);
    int main(int argc, char* argv[]) {
        std::cout << "Hello " << twice(argc) << std::endl;
    }
    """
    And a file named "project/src/deps.cpp" with:
    """
    int twice(int i) { return i * 2; }
    """
    And a file named "project/reggaefile.py" with:
    """
    from reggae import *
    b = Build(executable(name='app', src_dirs=['src']),
              optional(executable(name='opt', src_dirs=['opt_src'])))
    """
  And a file named "project/opt_src/opt.cpp" with:
  """
  #include <iostream>
  int main() {
     std::cout << "I'm optional!" << std::endl;
  }
  """

  @make
  Scenario: Make
    Given I successfully run `reggae -b make project`
    And I successfully run `make`
    Then a file named "app" should exist
    And a file named "opt" should not exist

    When I successfully run `./app`
    Then the output should contain:
    """
    Hello 2
    """

    When I successfully run `./app 1 2`
    Then the output should contain:
    """
    Hello 6
    """

    Given I successfully run `make opt`
    Then a file named "opt" should exist

    Given I successfully run `./opt`
    Then the output should contain:
    """
    I'm optional!
    """
