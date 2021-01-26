module tests.ut.code_command;

import reggae;
import unit_threaded;

int gCounter;
string[] gInputs;
string[] gOutputs;

private void incr(in string[] inputs, in string[] outputs) {
    gInputs = inputs.dup;
    gOutputs = outputs.dup;
    gCounter++;
}

private void reset() {
    gCounter = 0;
    gInputs = gOutputs = [];
}

@("Simple command") unittest {
    reset;
    auto tgt = Target("no output", &incr, Target("no input"));
    tgt.execute(Options());
    gCounter.shouldEqual(1);
    gInputs.shouldEqual(["no input"]);
    gOutputs.shouldEqual(["no output"]);
}


@("Remove build dir") unittest {
    reset;
    auto cmd = Command(&incr).expandVariables;
    cmd.execute(Options(), Language.unknown, [], []);
    gCounter.shouldEqual(1);
}
