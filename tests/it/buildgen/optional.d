module tests.it.buildgen.optional;


import tests.it.buildgen;
import std.file;


@("optional")
@Flaky
@Values("ninja", "make", "binary")
unittest {

    enum project = "opt";
    generateBuild!project;
    shouldBuild!project;

    "foo".shouldSucceed.shouldEqual(["hello foo"]);

    // default build only produces foo, not bar
    "bar".shouldNotExist;

    // explicitly request to build bar
    shouldBuild!project(["bar"]);
    "bar".shouldSucceed.shouldEqual(["hello bar"]);
}
