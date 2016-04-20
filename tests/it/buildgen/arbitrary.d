module tests.it.buildgen.arbitrary;

import reggae;
import unit_threaded;
import tests.utils;
import tests.it;


@("1st project builds")
@AutoTags
@Values("ninja", "make", "tup", "binary")
unittest {
    auto backend = getValue!string;
    auto options = testOptions(["-b", backend, inOrigPath("tests", "projects", "project1")]);
    doTestBuildFor!"project1.reggaefile"(options);

    auto testPath = options.workingDir;
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


@("2nd project builds")
@AutoTags
@Values("ninja", "make", "tup", "binary")
unittest {
    auto backend = getValue!string;
    auto options = testOptions(["-b", backend, inOrigPath("tests", "projects", "project2")]);
    doTestBuildFor!"project2.reggaefile"(options);

    auto testPath = options.workingDir;
    auto appPath = inPath(testPath, "appp");

    [appPath, "hello"].shouldExecuteOk(testPath).shouldEqual(
        ["Appending to hello yields hello appended!",
      ]);
    [appPath, "ohnoes"].shouldExecuteOk(testPath).shouldEqual(
        ["Appending to ohnoes yields ohnoes appended!",
            ]);
}
