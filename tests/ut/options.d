module tests.ut.options;

import unit_threaded;
import reggae.options;


@("per-module and all-at-once cannot be used together")
unittest {
    getOptions(["reggae", "-b", "ninja", "--per-module"]).shouldNotThrow;
    getOptions(["reggae", "-b", "ninja", "--all-at-once"]).shouldNotThrow;
    getOptions(["reggae", "-b", "ninja", "--per-module", "--all-at-once"]).shouldThrowWithMessage(
        "Cannot specify both --per-module and --all-at-once");
}
