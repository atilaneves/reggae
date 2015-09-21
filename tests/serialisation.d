module tests.serialisation;


import reggae;
import unit_threaded;

@safe:


void testShellCommand() {
    const command = Command("dmd -of$out -c $in");
    ubyte[] bytes = command.toBytes;
    Command.fromBytes(bytes).shouldEqual(command);
}
