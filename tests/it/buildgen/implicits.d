module tests.it.buildgen.implicits;

version(DigitalMars):

import tests.it.buildgen;
import reggae.path: buildPath;


static foreach (backend; ["ninja", "make", "binary"])
    @("Implicit dependencies cause the target to rebuild (" ~ backend ~ ")")
    @Tags(backend)
    unittest {
        enum project = "implicits";
        generateBuild!project(backend);
        shouldBuild!project;

        "leapp".shouldSucceed.shouldEqual(["Hello world!"]);

        overwrite(options, buildPath("string.txt"), "Goodbye!");
        shouldBuild!project;
        "leapp".shouldSucceed.shouldEqual(["Goodbye!"]);
    }
