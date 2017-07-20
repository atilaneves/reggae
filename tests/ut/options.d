module tests.ut.options;

import unit_threaded;
import reggae.options;


@("per_module and all_at_once cannot be used together")
unittest {
    getOptions(["reggae", "--per_module"]).shouldNotThrow;
    getOptions(["reggae", "--all_at_once"]).shouldNotThrow;
    getOptions(["reggae", "--per_module", "--all_at_once"]).shouldThrowWithMessage(
        "Cannot specify both --per_module and --all_at_once");
}
