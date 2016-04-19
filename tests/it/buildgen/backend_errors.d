module tests.it.buildgen.backend_errors;

import reggae;
mixin build!(Target(`foo`));

import reggae;
import reggae.reggae: run;
import unit_threaded;
import tests.it;


@("A backend must be specified") unittest {
    auto options = testOptions([inOrigPath("lvl1", "lvl2")]);
    doTestBuildFor!(__MODULE__)(options).shouldThrowWithMessage(
        "A backend must be specified with -b/--backend");
}

@("Backend option with non-supported backend must fail") unittest {
    auto backend = getValue!string;
    testOptions(["-b", inOrigPath("lvl1", "lvl2")]).shouldThrowWithMessage(
        "Unsupported backend, -b must be one of: make|ninja|tup|binary");

}

@("Export and backend cannot be used together") unittest {
    auto options = testOptions(["-b", "ninja", "--export", inOrigPath("lvl1", "lvl2")]);
    doTestBuildFor!(__MODULE__)(options).shouldThrowWithMessage(
        "Cannot specify a backend and export at the same time");
}
