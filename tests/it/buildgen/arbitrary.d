module tests.it.buildgen.arbitrary;

import reggae;
import unit_threaded;
import tests.utils;
import tests.it;

@("1st project builds with ninja") unittest {
    auto options = testOptions(["-b", "ninja", inOrigPath("tests", "projects", "project1")]);
    auto testPath = options.workingDir;
    doBuildFor!"project1.reggaefile"(options);
    ["ninja", "-j1"].shouldExecuteOk(testPath);
    auto appPath = inPath(testPath, "myapp");
    [appPath, "2", "3"].shouldExecuteOk(testPath).shouldEqual(
        ["The sum     of 2 and 3 is 5",
         "The product of 2 and 3 is 6",
      ]);
    [appPath, "3", "4"].shouldExecuteOk(testPath).shouldEqual(
        ["The sum     of 3 and 4 is 7",
         "The product of 3 and 4 is 12",
            ]);
}

@("2nd project builds with ninja") unittest {
    auto options = testOptions(["-b", "ninja", inOrigPath("tests", "projects", "project2")]);
    auto testPath = options.workingDir;

    doBuildFor!"project2.reggaefile"(options);
    ["ninja", "-j1"].shouldExecuteOk(testPath);
    auto appPath = inPath(testPath, "appp");
    [appPath, "hello"].shouldExecuteOk(testPath).shouldEqual(
        ["Appending to hello yields hello appended!",
      ]);
    [appPath, "ohnoes"].shouldExecuteOk(testPath).shouldEqual(
        ["Appending to ohnoes yields ohnoes appended!",
            ]);
}
