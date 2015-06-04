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
           auto c = File(buildPath(`gen`, args[1].baseName.stripExtension.defaultExtension(`.c`)), `w`);
           auto h = File(buildPath(`gen`, args[1].baseName.stripExtension.defaultExtension(`.h`)), `w`);
           auto reg = regex(`(\{.+?\})$`);
           foreach(line; file.byLine) {
               c.writeln(line);
               auto headerLine = line.replaceAll(reg, `;`);
               h.writeln(headerLine);
           }
      }
      """
    And I successfully run `dmd proj/compiler.d`
    And a file named "proj/translator.d" with:
      """
      import std.stdio;
      import std.path;
      import std.file;
      import std.exception;
      import std.conv;
      import std.algorithm;
      void main(string[] args) {
          enforce(args.length == 3, text(`Invalid translator args `, args));
          immutable dir = args[2].dirName;
          if(!dir.exists()) mkdir(dir);
          auto input  = File(args[1]);
          auto output = File(args[2], `w`);
          foreach(l; input.byLine) output.write(`extern(C) ` ~ l);
          output.writeln;
      }
      """
    And I successfully run `dmd proj/translator.d`
    And a file named "proj/reggaefile_sep.d" with:
      """
      import reggae;
      const protoC = Target(`$builddir/gen/protocol.c`,
                            `./compiler $in`,
                            [Target(`protocol.proto`)]);
      const protoH = Target(`$builddir/gen/protocol.h`,
                            `./compiler $in`,
                            [Target(`protocol.proto`)]);
      const protoObj = Target(`$builddir/bin/protocol.o`,
                              `gcc -o $out -c $in`,
                              [protoC]);
      const protoD = Target(`$builddir/gen/protocol.d`,
                            `./translator $in $out`,
                            [protoH]);
      const app = Target(`app`,
                         `dmd -of$out $in`,
                         [Target(`src/main.d`), protoObj, protoD]);
      mixin build!(app);
      """
    And a file named "proj/reggaefile_tog.d" with:
      """
      import reggae;
      const protoSrcs = Target([`$builddir/gen/protocol.c`, `$builddir/gen/protocol.h`],
                                `./compiler $in`,
                                [Target(`protocol.proto`)]);
      const protoObj = Target(`$builddir/bin/protocol.o`,
                              `gcc -o $out -c $builddir/gen/protocol.c`,
                              [], [protoSrcs]);
      const protoD = Target(`$builddir/gen/protocol.d`,
                            `./translator $builddir/gen/protocol.h $out`,
                            [], [protoSrcs]);
      const app = Target(`app`,
                         `dmd -of$out $in`,
                         [Target(`src/main.d`), protoObj, protoD]);
      mixin build!(app);
      """

    And a file named "proj/src/main.d" with:
      """
      import protocol;
      import std.stdio;
      import std.conv;
      void main(string[] args) {
          auto arg = args[1].to!int;
          writeln(`I call protoFunc(`, arg, `) and get `, protoFunc(arg));
      }
      """
    And a file named "proj/protocol.proto" with:
      """
      int protoFunc(int n) { return n * 2; }
      """

  Scenario: Ninja separate
      Given I successfully run `cp proj/reggaefile_sep.d proj/reggaefile.d`
      And I successfully run `reggae -b ninja proj`
      When I successfully run `ninja`
      And I successfully run `./app 2`
      Then the output should contain:
        """
        I call protoFunc(2) and get 4
        """
      Given I successfully run `sleep 1` for up to 2 seconds
      And I overwrite "proj/protocol.proto" with:
        """
        int protoFunc(int n) { return n * 3;}
        """
      When I successfully run `ninja`
      And I successfully run `./app 3`
      Then the output should contain:
        """
        I call protoFunc(3) and get 9
        """

    Scenario: Ninja together
      Given I successfully run `cp proj/reggaefile_tog.d proj/reggaefile.d`
      And I successfully run `reggae -b ninja proj`
      When I successfully run `ninja`
      And I successfully run `./app 2`
      Then the output should contain:
        """
        I call protoFunc(2) and get 4
        """

      Given I successfully run `sleep 1` for up to 2 seconds
      And I overwrite "proj/protocol.proto" with:
        """
        int protoFunc(int n) { return n * 3;}
        """
      When I successfully run `ninja`
      And I successfully run `./app 3`
      Then the output should contain:
        """
        I call protoFunc(3) and get 9
        """


    Scenario: Make separate
      Given I successfully run `cp proj/reggaefile_sep.d proj/reggaefile.d`
      And I successfully run `reggae -b make proj`
      When I successfully run `make -j8`
      And I successfully run `./app 2`
      Then the output should contain:
        """
        I call protoFunc(2) and get 4
        """

      Given I overwrite "proj/protocol.proto" with:
        """
        int protoFunc(int n) { return n * 3;}
        """
      When I successfully run `make -j8`
      And I successfully run `./app 3`
      Then the output should contain:
        """
        I call protoFunc(3) and get 9
        """

    Scenario: Make together
      Given I successfully run `cp proj/reggaefile_tog.d proj/reggaefile.d`
      And I successfully run `reggae -b make proj`
      When I successfully run `make -j8`
      And I successfully run `./app 2`
      Then the output should contain:
        """
        I call protoFunc(2) and get 4
        """

      Given I overwrite "proj/protocol.proto" with:
        """
        int protoFunc(int n) { return n * 3;}
        """
      When I successfully run `make -j8`
      And I successfully run `./app 3`
      Then the output should contain:
        """
        I call protoFunc(3) and get 9
        """
