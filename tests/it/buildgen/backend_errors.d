module tests.it.buildgen.backend_errors;

import tests.it.buildgen;
mixin build!(Target(`foo`));

@("A backend must be specified") unittest {
    _testOptions([inOrigPath("lvl1", "lvl2")]).shouldThrowWithMessage(
        "A backend must be specified with -b/--backend");
}

@("Backend option with non-supported backend must fail") unittest {
    _testOptions(["-b", inOrigPath("lvl1", "lvl2")]).shouldThrowWithMessage(
        "Unsupported backend, -b must be one of: make|ninja|tup|binary");

}

@("Export and backend cannot be used together") unittest {
    auto options = _testOptions(["-b", "ninja", "--export", inOrigPath("lvl1", "lvl2")]);
    doTestBuildFor!(__MODULE__)(options).shouldThrowWithMessage(
        "Cannot specify a backend and export at the same time");
}
