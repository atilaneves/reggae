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

@("--dflags and --dflag")
unittest {
    getOptions(["reggae", "--dflags=-a -b"]).dflags.should == ["-a", "-b"];
    getOptions(["reggae", "--dflags=-a", "--dflags=-b"]).dflags.should == ["-b"];

    getOptions(["reggae", "--dflag=-Imy dir"]).dflags.should == ["-Imy dir"];
    getOptions(["reggae", "--dflag=-a", "--dflag=-b"]).dflags.should == ["-a", "-b"];

    getOptions(["reggae", "--dflags=-a -b", "--dflag=-c", "--dflag=-d"]).dflags.should == ["-a", "-b", "-c", "-d"];
    getOptions(["reggae", "--dflags=-a -b", "--dflag=-c", "--dflag=-d", "--dflags=-e"]).dflags.should == ["-e", "-c", "-d"];
}
