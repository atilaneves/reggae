module tests.it.buildgen.phony;


import tests.it.buildgen;


@("Phony target always executed")
@AutoTags
@Values("ninja", "make", "binary")
unittest {

    enum project = "phony_proj";
    generateBuild!project;
    shouldBuild!project;

    // haven't run the binary yet, not output
    "output.txt".shouldNotExist;

    // "build" the phony target doit
    shouldBuild!project(["doit"]);
    "output.txt".shouldEqualLines(["It is done"]);

    // "rebuild" the phony target doit should cause it to run again
    shouldBuild!project(["doit"]);
    "output.txt".shouldEqualLines(["It is done", "It is done"]);
}
