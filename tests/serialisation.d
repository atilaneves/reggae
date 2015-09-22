module tests.serialisation;


import reggae;
import unit_threaded;

@safe:


void testShellCommand() {
    {
        const command = Command("dmd -of$out -c $in");
        ubyte[] bytes = command.toBytes;
        Command.fromBytes(bytes).shouldEqual(command);
    }

    {
        const command = Command("g++ -o $out -c $in");
        ubyte[] bytes = command.toBytes;
        Command.fromBytes(bytes).shouldEqual(command);
    }
}


void testBuiltinCommand() {
    {
        const command = Command(CommandType.compile, assocListT("foo", ["lefoo", "dasfoo"]));
        Command.fromBytes(command.toBytes).shouldEqual(command);
    }
    {
        const command = Command(CommandType.compile, assocListT("bar", ["lebar", "dasbar"]));
        Command.fromBytes(command.toBytes).shouldEqual(command);
    }
}


// void testTarget() {
//     const target = Target("foo.o", "dmd -of$out -c $in", Target("foo.d"));
//     Target.fromBytes(target.toBytes).shouldEqual(target);
// }
