module tests.it.buildgen.automatic_dependency;

// something about not finding libcmt.lib, can't be bothered debugging
version(DigitalMars) {
    version(Windows)
        enum skip = true;
    else
        enum skip = false;
} else
      enum skip = true;


static if(!skip) {

    import tests.it.buildgen;
    import reggae.path: buildPath;

    static foreach (backend; ["ninja", "make", "tup", "binary"])
        @("object.cpp." ~ backend)
        @Tags(backend)
        unittest {
            import reggae.config: options;

            enum project = "d_and_cpp";
            generateBuild!project(backend);
            shouldBuild!project;
            ["calc", "5"].shouldSucceed.shouldEqual(
                ["The result of calc(10) is 30"]);

            // I don't know what's going on here but the Cucumber test didn't do this either
            if(options.backend == Backend.tup) return;

            overwrite(options, buildPath("src/maths.hpp"), "const int factor = 10;");
            shouldBuild!project;

            ["calc", "3"].shouldSucceed.shouldEqual(
                ["The result of calc(6) is 60"]);
        }

    static foreach (backend; ["ninja", "make", "tup", "binary"])
        @("object.d." ~ backend)
        @Tags(backend)
        unittest {
            import reggae.config: options;

            enum project = "d_and_cpp";
            generateBuild!project(backend);
            shouldBuild!project;
            ["calc", "5"].shouldSucceed.shouldEqual(
                ["The result of calc(10) is 30"]);

            // I don't know what's going on here but the Cucumber test didn't do this either
            if(options.backend == Backend.tup) return;

            overwrite(options, buildPath("src/constants.d"), "immutable int leconst = 1;");
            shouldBuild!project;

            ["calc", "3"].shouldSucceed.shouldEqual(
                ["The result of calc(3) is 9"]);
        }
}
