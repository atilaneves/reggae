module tests.it.buildgen.optional;


import tests.it;
import tests.utils;


@("optional")
@Values("ninja", "make", "binary")
unittest {
    import std.file;

    enum module_ = "opt.reggaefile";
    auto options = testProjectOptions!module_;

    // default build only produces foo, not bar
    doTestBuildFor!module_(options);

    auto fooPath = inPath(options, "foo");
    fooPath.shouldExecuteOk(options).shouldEqual(["hello foo"]);

    auto barPath = inPath(options, "bar");
    barPath.exists.shouldBeFalse;

    // explicitly request to build bar
    buildCmdShouldRunOk!module_(options, ["bar"]);
    barPath.shouldExecuteOk(options).shouldEqual(["hello bar"]);
}
