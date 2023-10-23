module tests.it.buildgen.optional;

version(DigitalMars):

import tests.it.buildgen;
import std.file;


static foreach (backend; ["ninja", "make", "binary"])
    @("optional." ~ backend)
    @Flaky
    @Tags(backend)
    unittest {

        enum project = "opt";
        generateBuild!project(backend);
        shouldBuild!project;

        "foo".shouldSucceed.shouldEqual(["hello foo"]);

        // default build only produces foo, not bar
        "bar".shouldNotExist;

        // explicitly request to build bar
        shouldBuild!project(["bar"]);
        "bar".shouldSucceed.shouldEqual(["hello bar"]);
    }
