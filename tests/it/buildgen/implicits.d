module tests.it.buildgen.implicits;


import tests.it.buildgen;


@("Implicit dependencies cause the target to rebuild")
@AutoTags
@Values("ninja", "make", "binary")
unittest {
    enum project = "implicits";
    generateBuild!project;
    shouldBuild!project;

    "leapp".shouldSucceed.shouldEqual(["Hello world!"]);

    overwrite(options, buildPath("string.txt"), "Goodbye!");
    shouldBuild!project;
    "leapp".shouldSucceed.shouldEqual(["Goodbye!"]);
}
