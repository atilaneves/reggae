module tests.ut.serialisation;


import reggae;
import reggae.options;
import reggae.path: buildPath;
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
    import reggae.config: gDefaultOptions;
    auto target = Target("foo.o", "dmd -of$out -c $in", Target("foo.d"));
    auto bytes = target.toBytes(gDefaultOptions.withProjectPath("/path/to"));
    enum srcPath = buildPath("/path/to/foo.d");
    Target.fromBytes(bytes).shouldEqual(
        Target("foo.o", "dmd -offoo.o -c " ~ srcPath, Target(srcPath)));
}

void testBuild() @trusted {
    import reggae.config: gDefaultOptions;
    auto foo = Target("foo.o", "dmd -of$out -c $in", Target("foo.d"));
    auto bar = Target("bar.o", "dmd -of$out -c $in", Target("bar.d"));
    auto build = Build(foo, bar);
    auto bytes = build.toBytes(gDefaultOptions.withProjectPath("/path/to"));
    enum srcFoo = buildPath("/path/to/foo.d");
    enum srcBar = buildPath("/path/to/bar.d");
    Build.fromBytes(bytes).shouldEqual(
        Build(Target("foo.o", "dmd -offoo.o -c " ~ srcFoo, Target(srcFoo)),
              Target("bar.o", "dmd -ofbar.o -c " ~ srcBar, Target(srcBar))));
}
