Feature: Multiple outputs
  As a user of reggae
  I want to be able to specify multiple outputs
  So that I can have realistic builds

  Background:
    Given a file named "proj/compiler.d" with:
      """
      import std.stdio;
      import std.regex;
      import std.path;
      void main(string[] args) {
           auto file = File(args[1]);
           auto cpp = File(args[1].stripExtension.defaultExtension(`.cpp`), `w`);
           auto hpp = File(args[1].stripExtension.defaultExtension(`.hpp`), `w`);
           auto reg = regex(`(\{.+?\})$`);
           foreach(line; file.byLine) {
               cpp.writeln(line);
               auto headerLine = line.replaceAll(reg, `;`);
               hpp.writeln(headerLine);
           }
      }
      """
    And I successfully run `dmd proj/compiler.d`
    And a file named "proj/reggaefile.d" with:
      """
      import reggae;
      const protoGen = Target([`protocol.hpp`, `protocol.cpp`],
                              `./compiler $in`,
                              [Target(`protocol.proto`)]);
      const proto = Target(`bin/protocol.o`, `g++ -o $out -c protocol.cpp`, [protoGen]);
      const protoD = Target(`src/protocol.d`, `cp protocol.hpp protocol.d`, [Target(`protocol.h`)]);
      const app = Target(`bin/app`, `dmd -of$out $in`,
                         [Target(`src/main.d`), proto, protoD]);
      mixin build!(app);
      """
    And a file named "proj/src/main.d" with:
      """
      import protocol;
      import std.stdio;
      import std.conv;
      void main(string[] args) {
          auto arg = args[1].to!int;
          writeln(`I call protoFunc(`, arg, `) and get `, protofunc(arg));
      }
      """
    And a file named "proj/protocol.proto" with:
      """
      int protoFunc(int n) { return n * 2; }
      """

    Scenario: Make
      Given I successfully run `reggae -b make proj`
      When I successfully run `make -j8`
      And I successfully run `bin/app 2`
      Then the output should contain:
        """
        I call protoFunc(2) and get 4
        """

      Given I overwrite "proj/protocol.proto" with:
        """
        int protoFunc(int n) { return n * 3;}
        """
      When I successfully run `make -j8`
      And I successfully run `bin/app 3`
      Then the output should contain:
        """
        I call protoFunc(3) and get 9
        """
