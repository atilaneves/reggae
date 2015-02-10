module tests.ninja;

import unit_threaded;
import reggae.ninja;
import reggae.build;


void testCreateNinjaRule() {
    auto ninja = Ninja();
    const target = Target("mytarget", [Target("med1"), Target("med2"), Target("med3")],
                          "by_your_command $in $out");
    ninja.addTarget(target);
    ninja.buildLines.shouldEqual(["build mytarget: by_your_command med1 med2 med3",
                                  ""]);
    ninja.ruleLines.shouldEqual(["rule by_your_command",
                                 "  command = by_your_command $in $out",
                                 ""]);

    //make sure calling it again doesn't add the same rule
    ninja.addTarget(target);
    ninja.buildLines.shouldEqual(["build mytarget: by_your_command med1 med2 med3",
                                  ""]);
    ninja.ruleLines.shouldEqual(["rule by_your_command",
                                 "  command = by_your_command $in $out",
                                 ""]);

    //but adding something different should have an effect
    ninja.addTarget(Target("med2", [Target("file2_1"), Target("file2_2")],
                           "medcmd $out $in"));
    ninja.buildLines.shouldEqual(["build mytarget: by_your_command med1 med2 med3",
                                  "",
                                  "build med2: medcmd file2_1 file2_2",
                                  ""]);
}
