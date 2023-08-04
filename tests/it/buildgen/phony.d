module tests.it.buildgen.phony;


import tests.it.buildgen;


static foreach (backend; ["ninja", "make", "binary"])
    @(backend ~ ".always_executed")
    @Tags(backend)
    @Flaky
    unittest {

        enum project = "phony_proj";
        generateBuild!project(backend);
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
