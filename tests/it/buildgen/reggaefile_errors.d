module tests.it.buildgen.reggaefile_errors;


import reggae.buildgen;
import unit_threaded;
import tests.it;


@("Empty build description") unittest {
    auto options = _testOptions(["-b", "ninja"]);
    doBuildFor!("tests.it.buildgen.empty_reggaefile")(options).shouldThrowWithMessage(
        "Could not find a public function with return type Build in tests.it.buildgen.empty_reggaefile");
}

@("Too many builds in description") unittest {
    auto options = _testOptions(["-b", "ninja"]);
    doBuildFor!("tests.it.buildgen.two_builds_reggaefile")(options).shouldThrowWithMessage(
        "Only one build object allowed per module, tests.it.buildgen.two_builds_reggaefile has 2");
}
