module tests.it.buildgen.reggaefile_errors;


import reggae.buildgen;
import unit_threaded;
import tests.it;


@("Empty build description") unittest {
    auto options = testOptions(["-b", "ninja"]);
    doBuildFor!("tests.it.buildgen.empty_reggaefile")(options).shouldThrowWithMessage(
        "No `Build reggaeBuild()` function in tests.it.buildgen.empty_reggaefile");
}

@("Too many builds in description") unittest {
    auto options = testOptions(["-b", "ninja"]);
    doBuildFor!("tests.it.buildgen.two_builds_reggaefile")(options).shouldThrowWithMessage(
        "No `Build reggaeBuild()` function in tests.it.buildgen.two_builds_reggaefile");
}
