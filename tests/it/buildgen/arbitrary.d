module tests.it.buildgen.arbitrary;


version(DigitalMars):


import tests.it.buildgen;


static foreach (backend; ["ninja", "make", "tup", "binary"])
    @("1st project builds (" ~ backend ~ ")")
    @Tags(backend)
    unittest {
        enum project = "project1";
        generateBuild!project(backend);
        shouldBuild!project;

        ["myapp", "2", "3"].shouldSucceed.shouldEqual(
            ["The sum     of 2 and 3 is 5",
             "The product of 2 and 3 is 6",
          ]);

        ["myapp", "3", "4"].shouldSucceed.shouldEqual(
            ["The sum     of 3 and 4 is 7",
             "The product of 3 and 4 is 12",
                ]);
    }


static foreach (backend; ["ninja", "make", "tup", "binary"])
    @("2nd project builds (" ~ backend ~ ")")
    @Tags(backend)
    unittest {
        enum project = "project2";
        generateBuild!project(backend);
        shouldBuild!project;

        ["appp", "hello"].shouldSucceed.shouldEqual(
            ["Appending to hello yields hello appended!"]);

        ["appp", "ohnoes"].shouldSucceed.shouldEqual(
            ["Appending to ohnoes yields ohnoes appended!"]);
    }
