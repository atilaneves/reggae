module tests.ninja;

import unit_threaded;
import reggae.ninja;
import reggae.build;


void testEmpty() {
    auto ninja = Ninja();
    ninja.buildLines.shouldEqual([]);
    ninja.ruleLines.shouldEqual([]);
}


void testNinjaSimple() {
    auto ninja = Ninja();
    const target = Target("mytarget", [Target("med1"), Target("med2"), Target("med3")],
                          "by_your_command $in $out");
    ninja.addTarget(target);
    ninja.buildLines.shouldEqual([NinjaEntry("build mytarget: by_your_command med1 med2 med3")]);
    ninja.ruleLines.shouldEqual([NinjaEntry("rule by_your_command",
                                            ["  command = by_your_command $in $out"])
                                    ]);

    //make sure calling it again doesn't add the same rule
    ninja.addTarget(target);
    ninja.buildLines.shouldEqual([NinjaEntry("build mytarget: by_your_command med1 med2 med3")]);
    ninja.ruleLines.shouldEqual([NinjaEntry("rule by_your_command",
                                            ["  command = by_your_command $in $out"])
                                    ]);

    //but adding something different should have an effect
    ninja.addTarget(Target("med2", [Target("file2_1"), Target("file2_2")],
                           "medcmd $out $in"));
    ninja.buildLines.shouldEqual([NinjaEntry("build mytarget: by_your_command med1 med2 med3"),
                                  NinjaEntry("build med2: medcmd file2_1 file2_2")]);
}


@ShouldFail
void testCppLinker() {
    auto ninja = Ninja();
    ninja.addTarget(Target("mybin",
                           [Target("foo.o"), Target("bar.o")],
                           "/usr/bin/c++ $in -o $out""command"));
    ninja.buildLines.shouldEqual([NinjaEntry("build mybin: cpp foo.o bar.o",
                                              ["  between = -o"])
                                     ]);
    ninja.ruleLines.shouldEqual([NinjaEntry("rule cpp",
                                            ["  command = /usr/bin/c++ $in $between $out"])
                                    ]);
}
