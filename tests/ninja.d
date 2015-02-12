module tests.ninja;

import unit_threaded;
import reggae.ninja;
import reggae.build;


void testEmpty() {
    auto ninja = Ninja();
    ninja.buildEntries.shouldEqual([]);
    ninja.ruleEntries.shouldEqual([]);
}


void testNinjaSimple() {
    auto ninja = Ninja();
    const target = Target("mytarget", [Target("med1"), Target("med2"), Target("med3")],
                          "by_your_command $in $out");
    ninja.addTarget(target);
    ninja.buildEntries.shouldEqual([NinjaEntry("build mytarget: by_your_command med1 med2 med3")]);
    ninja.ruleEntries.shouldEqual([NinjaEntry("rule by_your_command",
                                              ["command = by_your_command $in $out"])
                                      ]);

    //make sure calling it again doesn't add the same rule
    ninja.addTarget(target);
    ninja.buildEntries.shouldEqual([NinjaEntry("build mytarget: by_your_command med1 med2 med3")]);
    ninja.ruleEntries.shouldEqual([NinjaEntry("rule by_your_command",
                                              ["command = by_your_command $in $out"])
                                      ]);

    //but adding something different should have an effect
    ninja.addTarget(Target("med2", [Target("file2_1"), Target("file2_2")],
                           "medcmd $out $in"));
    ninja.buildEntries.shouldEqual([NinjaEntry("build mytarget: by_your_command med1 med2 med3"),
                                    NinjaEntry("build med2: medcmd file2_1 file2_2")]);
}


void testCppLinker() {
    auto ninja = Ninja();
    ninja.addTarget(Target("mybin",
                           [Target("foo.o"), Target("bar.o")],
                           "/usr/bin/c++ $in -o $out"));
    ninja.buildEntries.shouldEqual([NinjaEntry("build mybin: cpp foo.o bar.o",
                                               ["between = -o"])
                                       ]);
    ninja.ruleEntries.shouldEqual([NinjaEntry("rule cpp",
                                              ["command = /usr/bin/c++ $in $between $out"])
                                      ]);
}


void testIccBuild() {
    auto ninja = Ninja();
    ninja.addTarget(Target("/path/to/foo.o", [Target("/path/to/foo.c")],
                           "icc.12.0.022b.i686-linux -pe-file-prefix=/usr/intel/12.0.022b/cc/12.0.022b/include/ @/usr/lib/icc-cc.cfg -I/path/to/headers -gcc-version=345 -fno-strict-aliasing -nostdinc -include /path/to/myheader.h -DTOOL_CHAIN_GCC=gcc-user -D__STUFF__ -imacros /path/to/preinclude_macros.h -I/path/to -Wall -c -MD -MF /path/to/foo.d -o $out $in"));
    ninja.buildEntries.shouldEqual([NinjaEntry("build /path/to/foo.o: icc.12.0.022b.i686-linux /path/to/foo.c",
                                               ["before = -pe-file-prefix=/usr/intel/12.0.022b/cc/12.0.022b/include/ @/usr/lib/icc-cc.cfg -I/path/to/headers -gcc-version=345 -fno-strict-aliasing -nostdinc -include /path/to/myheader.h -DTOOL_CHAIN_GCC=gcc-user -D__STUFF__ -imacros /path/to/preinclude_macros.h -I/path/to -Wall -c -MD -MF /path/to/foo.d -o"])]);
    ninja.ruleEntries.shouldEqual([NinjaEntry("rule icc.12.0.022b.i686-linux",
                                              ["command = icc.12.0.022b.i686-linux $before $out $in"])]);
}


void testBeforeAndAfter() {
    auto ninja = Ninja();
    ninja.addTarget(Target("foo.temp",
                           [Target("main.o"), Target("extra.o"), Target("sub_foo.o"), Target("sub_bar.o"),
                            Target("sub_baz.a")],
                           "icc @/path/to/icc-ld.cfg -o $out $in -Wl,-rpath-link -Wl,/usr/lib"));
    ninja.buildEntries.shouldEqual([NinjaEntry("build foo.temp: icc main.o extra.o sub_foo.o sub_bar.o sub_baz.a",
                                               ["before = @/path/to/icc-ld.cfg -o",
                                                "after = -Wl,-rpath-link -Wl,/usr/lib"])]);
    ninja.ruleEntries.shouldEqual([NinjaEntry("rule icc",
                                              ["command = icc $before $out $in $after"])]);
}
