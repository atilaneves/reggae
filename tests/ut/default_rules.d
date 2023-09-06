module tests.ut.default_rules;


import reggae;
import unit_threaded;
import std.array;


@("No default rule") unittest {
    Command("doStuff foo=bar").isDefaultCommand.shouldBeFalse;
}

@("Get rule D") unittest {
    const command = Command(CommandType.compile, assocList([assocEntry("foo", ["bar"])]));
    command.getType.shouldEqual(CommandType.compile);
    command.isDefaultCommand.shouldBeTrue;
}

@("Get rule C++") unittest {
    const command = Command(CommandType.compile, assocList([assocEntry("includes", ["src", "other"])]));
    command.getType.shouldEqual(CommandType.compile);
    command.isDefaultCommand.shouldBeTrue;
}


@("Value when key not found") unittest {
    const command = Command(CommandType.compile, assocList([assocEntry("foo", ["bar"])]));
    command.getParams("", "foo", ["hahaha"]).shouldEqual(["bar"]);
    command.getParams("", "includes", ["hahaha"]).shouldEqual(["hahaha"]);
}


@("objectFile") unittest {
    auto obj = objectFile(Options(), SourceFile("path/to/src/foo.c"), Flags("-m64 -fPIC -O3"));
    obj.hasDefaultCommand.shouldBeTrue;

    auto build = Build(objectFile(Options(), SourceFile("path/to/src/foo.c"), Flags("-m64 -fPIC -O3")));
    build.targets.array[0].hasDefaultCommand.shouldBeTrue;
}
