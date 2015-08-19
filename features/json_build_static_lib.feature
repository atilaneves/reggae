@python
Feature: Foreign language integration - link
  As a reggae user
  I want to be able to write build descriptions in a scripting language
  So I don't have to compile the build description

  Background:
    Given a file named "path/to/reggaefile.py" with:
      """
      from reggae import *
      lib = static_library('libsrc.a',  flags='-I$project/src', src_dirs=['src'])
      app = link(exe_name='myapp',
                 dependencies=lib,
                 flags='-L-M')
      bld = Build(app)
      """
    And a file named "path/to/src/main.cpp" with:
      """
      #include <iostream>
      #include <cstdlib>
      using namespace std;

      extern int adder(int, int);
      extern int prodder(int, int);

      int main(int argc, char* argv[]) {
          const int a = atoi(argv[1]);
          const int b = atoi(argv[2]);
          cout << "The sum     of " << a << " and " << b << " is " << adder(a, b) << endl;
          cout << "The product of " << a << " and " << b << " is " << prodder(a, b) << endl;
      }
      """
    And a file named "path/to/src/maths.cpp" with:
      """
      int adder(int a, int b) { return a + b; }
      int prodder(int a, int b) { return a * b; }
      """

    @ninja
    Scenario: Ninja build with python
      Given I successfully run `reggae -b ninja path/to`
      When I successfully run `ninja`
      Then a file named "libsrc.a" should exist
      When I successfully run `./myapp 2 3`
      Then the output should contain:
        """
        The sum     of 2 and 3 is 5
        The product of 2 and 3 is 6
        """
      When I run `./myapp 3 4`
      Then the output should contain:
        """
        The sum     of 3 and 4 is 7
        The product of 3 and 4 is 12
        """

    @make
    Scenario: Make build with python
      Given I successfully run `reggae -b make path/to`
      When I successfully run `make`
      Then a file named "libsrc.a" should exist
      When I successfully run `./myapp 2 3`
      Then the output should contain:
        """
        The sum     of 2 and 3 is 5
        The product of 2 and 3 is 6
        """
      When I run `./myapp 3 4`
      Then the output should contain:
        """
        The sum     of 3 and 4 is 7
        The product of 3 and 4 is 12
        """

    @tup
    Scenario: Tup build with python
      Given I successfully run `reggae -b tup path/to`
      When I successfully run `tup`
      Then a file named "libsrc.a" should exist
      When I successfully run `./myapp 2 3`
      Then the output should contain:
        """
        The sum     of 2 and 3 is 5
        The product of 2 and 3 is 6
        """
      When I run `./myapp 3 4`
      Then the output should contain:
        """
        The sum     of 3 and 4 is 7
        The product of 3 and 4 is 12
        """

    @binary
    Scenario: Binary build with python
      When I run `reggae -b binary path/to`
      Then it should fail with:
        """
        Binary backend not supported via JSON
        """
