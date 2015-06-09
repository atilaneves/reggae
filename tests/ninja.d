module tests.ninja;

import unit_threaded;
import reggae.backend.ninja;
import reggae.build;


void testEmpty() {
    const ninja = Ninja();
    ninja.buildEntries.shouldEqual([]);
    ninja.ruleEntries.shouldEqual([]);
}

void testCppLinker() {
    const ninja = Ninja(Build(Target("mybin",
                                     "/usr/bin/c++ $in -o $out",
                                     [Target("foo.o"), Target("bar.o")],
                                  )));
    ninja.buildEntries.shouldEqual([NinjaEntry("build mybin: cpp foo.o bar.o",
                                               ["between = -o"])
                                       ]);
    ninja.ruleEntries.shouldEqual([NinjaEntry("rule cpp",
                                              ["command = /usr/bin/c++ $in $between $out"])
                                      ]);
}

void testCppLinkerProjectPath() {
    const ninja = Ninja(Build(Target("mybin",
                                     "/usr/bin/c++ $in -o $out",
                                     [Target("foo.o"), Target("bar.o")],
                                  )),
                        "/home/user/myproject");
    ninja.buildEntries.shouldEqual([NinjaEntry("build mybin: cpp /home/user/myproject/foo.o /home/user/myproject/bar.o",
                                               ["between = -o"])
                                       ]);
    ninja.ruleEntries.shouldEqual([NinjaEntry("rule cpp",
                                              ["command = /usr/bin/c++ $in $between $out"])
                                      ]);
}


void testCppLinkerProjectPathAndBuild() {
    const ninja = Ninja(Build(Target("mybin",
                                     "/usr/bin/c++ $in -o $out",
                                     [Target("foo.o"), Target("bar.o")],
                                  )),
                        "/home/user/myproject");
    ninja.buildEntries.shouldEqual([NinjaEntry("build mybin: cpp /home/user/myproject/foo.o /home/user/myproject/bar.o",
                                               ["between = -o"])
                                       ]);
    ninja.ruleEntries.shouldEqual([NinjaEntry("rule cpp",
                                              ["command = /usr/bin/c++ $in $between $out"])
                                      ]);
}


void testIccBuild() {
    const ninja = Ninja(Build(Target("/path/to/foo.o",
                                     "icc.12.0.022b.i686-linux -pe-file-prefix=/usr/intel/12.0.022b/cc/12.0.022b/include/ @/usr/lib/icc-cc.cfg -I/path/to/headers -gcc-version=345 -fno-strict-aliasing -nostdinc -include /path/to/myheader.h -DTOOL_CHAIN_GCC=gcc-user -D__STUFF__ -imacros /path/to/preinclude_macros.h -I/path/to -Wall -c -MD -MF /path/to/foo.d -o $out $in",
                                     [Target("/path/to/foo.c")])));
    ninja.buildEntries.shouldEqual([NinjaEntry("build /path/to/foo.o: icc.12.0.022b.i686-linux /path/to/foo.c",
                                               ["before = -pe-file-prefix=/usr/intel/12.0.022b/cc/12.0.022b/include/ @/usr/lib/icc-cc.cfg -I/path/to/headers -gcc-version=345 -fno-strict-aliasing -nostdinc -include /path/to/myheader.h -DTOOL_CHAIN_GCC=gcc-user -D__STUFF__ -imacros /path/to/preinclude_macros.h -I/path/to -Wall -c -MD -MF /path/to/foo.d -o"])]);
    ninja.ruleEntries.shouldEqual([NinjaEntry("rule icc.12.0.022b.i686-linux",
                                              ["command = icc.12.0.022b.i686-linux $before $out $in"])]);
}


void testBeforeAndAfter() {
    const ninja = Ninja(Build(Target("foo.temp",
                                     "icc @/path/to/icc-ld.cfg -o $out $in -Wl,-rpath-link -Wl,/usr/lib",
                                     [Target("main.o"), Target("extra.o"), Target("sub_foo.o"), Target("sub_bar.o"),
                                      Target("sub_baz.a")])));
    ninja.buildEntries.shouldEqual([NinjaEntry("build foo.temp: icc main.o extra.o sub_foo.o sub_bar.o sub_baz.a",
                                               ["before = @/path/to/icc-ld.cfg -o",
                                                "after = -Wl,-rpath-link -Wl,/usr/lib"])]);
    ninja.ruleEntries.shouldEqual([NinjaEntry("rule icc",
                                              ["command = icc $before $out $in $after"])]);
}

void testSimpleDBuild() {
    const mainObj  = Target(`main.o`,  `dmd -I$project/src -c $in -of$out`, Target(`src/main.d`));
    const mathsObj = Target(`maths.o`, `dmd -c $in -of$out`, Target(`src/maths.d`));
    const app = Target(`myapp`,
                       `dmd -of$out $in`,
                       [mainObj, mathsObj]
        );
    const build = Build(app);
    const ninja = Ninja(build, "/path/to/project");

    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build objs/myapp.objs/main.o: dmd /path/to/project/src/main.d",
                    ["before = -I/path/to/project/src -c",
                     "between = -of"]),
         NinjaEntry("build objs/myapp.objs/maths.o: dmd /path/to/project/src/maths.d",
                    ["before = -c",
                     "between = -of"]),
         NinjaEntry("build myapp: dmd_2 objs/myapp.objs/main.o objs/myapp.objs/maths.o",
                    ["before = -of"])
            ]);

    ninja.ruleEntries.shouldEqual(
        [NinjaEntry("rule dmd",
                    ["command = dmd $before $in $between$out"]),
         NinjaEntry("rule dmd_2",
                    ["command = dmd $before$out $in"])
            ]);
}


void testImplicitDependencies() {
    const target = Target("foo.o", "gcc -o $out -c $in", [Target("foo.c")], [Target("foo.h")]);
    const ninja = Ninja(Build(target));
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build foo.o: gcc foo.c | foo.h",
                    ["before = -o",
                     "between = -c"])
            ]);

    ninja.ruleEntries.shouldEqual(
        [NinjaEntry("rule gcc",
                    ["command = gcc $before $out $between $in"])]);
}

void testImplicitDependenciesMoreThanOne() {
    const target = Target("foo.o", "gcc -o $out -c $in", [Target("foo.c")], [Target("foo.h"), Target("foo.idl")]);
    const ninja = Ninja(Build(target));
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build foo.o: gcc foo.c | foo.h foo.idl",
                    ["before = -o",
                     "between = -c"])
            ]);

    ninja.ruleEntries.shouldEqual(
        [NinjaEntry("rule gcc",
                    ["command = gcc $before $out $between $in"])]);
}


void testDefaultRules() {
    defaultRules().shouldEqual(
        [NinjaEntry("rule _dcompile",
                    ["command = .reggae/dcompile --objFile=$out --depFile=$DEPFILE dmd $flags $includes $stringImports $in",
                     "deps = gcc",
                     "depfile = $DEPFILE"]),
         NinjaEntry("rule _link",
                    ["command = dmd $flags -of$out $in"]),
         NinjaEntry("rule _cppcompile",
                    ["command = g++ $flags $includes -MMD -MT $out -MF $DEPFILE -o $out -c $in",
                     "deps = gcc",
                     "depfile = $DEPFILE"]),
         NinjaEntry("rule _ccompile",
                    ["command = gcc $flags $includes -MMD -MT $out -MF $DEPFILE -o $out -c $in",
                     "deps = gcc",
                     "depfile = $DEPFILE"]),
            ]);
}


void testImplicitOutput() {
    const foo = Target(["foo.h", "foo.c"], "protocomp $in", [Target("foo.proto")]);
    const bar = Target(["bar.h", "bar.c"], "protocomp $in", [Target("bar.proto")]);
    const ninja = Ninja(Build(foo, bar));

    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build foo.h foo.c: protocomp foo.proto"),
         NinjaEntry("build bar.h bar.c: protocomp bar.proto")]);

    ninja.ruleEntries.shouldEqual(
        [NinjaEntry("rule protocomp",
                    ["command = protocomp $in "])]);
}


void testImplicitInput() {
    const protoSrcs = Target([`$builddir/gen/protocol.c`, `$builddir/gen/protocol.h`],
                             `./compiler $in`,
                             [Target(`protocol.proto`)]);
    const protoObj = Target(`$builddir/bin/protocol.o`,
                            `gcc -o $out -c $builddir/gen/protocol.c`,
                            [], [protoSrcs]);
    const protoD = Target(`$builddir/gen/protocol.d`,
                          `./translator $builddir/gen/protocol.h $out`,
                          [], [protoSrcs]);
    const app = Target(`app`, `dmd -of$out $in`,
                       [Target("src/main.d"), protoObj, protoD]);

    const ninja = Ninja(Build(app));

    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build gen/protocol.c gen/protocol.h: compiler protocol.proto"),
         NinjaEntry("build bin/protocol.o: gcc gen/protocol.c | gen/protocol.c gen/protocol.h",
                    ["before = -o",
                     "between = -c"]),
         NinjaEntry("build gen/protocol.c gen/protocol.h: compiler protocol.proto"),
         NinjaEntry("build gen/protocol.d: translator gen/protocol.h | gen/protocol.c gen/protocol.h"),
         NinjaEntry("build app: dmd src/main.d bin/protocol.o gen/protocol.d",
                    ["before = -of"])
            ]);

    ninja.ruleEntries.shouldEqual(
        [NinjaEntry("rule compiler",
                    ["command = ./compiler $in "]),
         NinjaEntry("rule gcc",
                    ["command = gcc $before $out $between $in"]),
         NinjaEntry("rule translator",
                    ["command = ./translator $in $out"]),
         NinjaEntry("rule dmd",
                    ["command = dmd $before$out $in"])
            ]);
}
