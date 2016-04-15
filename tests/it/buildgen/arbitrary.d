module tests.it.buildgen.arbitrary;

import reggae;
import unit_threaded;
import tests.utils;
import tests.it;


@Serial
@("first project builds with ninja") unittest {
    auto options = getOptions(["reggae", "-b", "ninja",
                               inOrigPath("tests", "projects", "project1")
                               ]);
    doBuildFor(options);
    ["ninja", "-j" "1"].shouldExecuteOk;
    auto appPath = inTestPath("myapp");
    [appPath, "2", "3"].shouldExecuteOk.shouldEqual(
        ["The sum     of 2 and 3 is 5",
         "The product of 2 and 3 is 6",
      ]);
    [appPath, "3", "4"].shouldExecuteOk.shouldEqual(
        ["The sum     of 3 and 4 is 7",
         "The product of 3 and 4 is 12",
            ]);
}
