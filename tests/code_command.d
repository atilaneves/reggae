module tests.code_command;

import reggae;
import unit_threaded;

int counter;

private void incr(in string[] inputs, in string[] outputs) {
    inputs.shouldEqual(["no input"]);
    outputs.shouldEqual(["no output"]);
    counter++;
}

void testSimpleCommand() {
    counter.shouldEqual(0);
    const tgt = Target("no output", &incr, Target("no input"));
    tgt.execute();
    counter.shouldEqual(1);
}
