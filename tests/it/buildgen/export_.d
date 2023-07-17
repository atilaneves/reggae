module tests.it.buildgen.export_;


import tests.it.buildgen;
import tests.utils;
import std.conv;


static foreach (backend; ["ninja", "make", "tup"])
    @(backend)
    @Tags(backend)
    unittest {
        auto options = testOptions(["--export", projectPath("export_proj")]);
        enum module_ = "export_proj.reggaefile";
        doTestBuildFor!module_(options);

        // no app yet, just exported the build
        "hello".shouldFail;

        // try one of the build systems and build the app
        const testPath = options.workingDir;
        buildCmd(backend.to!Backend, testPath).shouldExecuteOk(WorkDir(testPath));

        // it should now run ok
        "hello".shouldSucceed.shouldEqual(["Hello world!"]);
    }
