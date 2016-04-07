module tests.serialisation;


import reggae;
import reggae.options;
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


void testTarget() {
    import reggae.config: options;
    auto target = Target("foo.o", "dmd -of$out -c $in", Target("foo.d"));
    auto bytes = target.toBytes(options.withProjectPath("/path/to"));
    Target.fromBytes(bytes).shouldEqual(
        Target("foo.o", "dmd -offoo.o -c /path/to/foo.d", Target("/path/to/foo.d")));
}

void testBuild() @trusted {
    import reggae.config: options;
    auto foo = Target("foo.o", "dmd -of$out -c $in", Target("foo.d"));
    auto bar = Target("bar.o", "dmd -of$out -c $in", Target("bar.d"));
    auto build = Build(foo, bar);
    auto bytes = build.toBytes(options.withProjectPath("/path/to"));
    Build.fromBytes(bytes).shouldEqual(
        Build(Target("foo.o", "dmd -offoo.o -c /path/to/foo.d", Target("/path/to/foo.d")),
              Target("bar.o", "dmd -ofbar.o -c /path/to/bar.d", Target("/path/to/bar.d"))));
}
