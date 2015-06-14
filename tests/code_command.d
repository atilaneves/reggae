module tests.code_command;

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

void testSimpleCommand() {
    gCounter = 0;
    const tgt = Target("no output", &incr, Target("no input"));
    tgt.execute();
    gCounter.shouldEqual(1);
    gInputs.shouldEqual(["no input"]);
    gOutputs.shouldEqual(["no output"]);
}


void testRemoveBuildDir() {
    gCounter = 0;
    const cmd = Command(&incr).expandBuildDir;
    cmd.execute("", [], []);
    gCounter.shouldEqual(1);
}
