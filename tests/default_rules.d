module tests.default_rules;


import reggae;
import unit_threaded;


void testNoDefaultRule() {
    Command("doStuff foo=bar").isDefaultCommand.shouldBeFalse;
}

void testGetRuleD() {
    const command = Command(CommandType.compile, assocList([assocEntry("foo", ["bar"])]));
    command.getType.shouldEqual(CommandType.compile);
    command.isDefaultCommand.shouldBeTrue;
}

void testGetRuleCpp() {
    const command = Command(CommandType.compile, assocList([assocEntry("includes", ["src", "other"])]));
    command.getType.shouldEqual(CommandType.compile);
    command.isDefaultCommand.shouldBeTrue;
}


void testValueWhenKeyNotFound() {
    const command = Command(CommandType.compile, assocList([assocEntry("foo", ["bar"])]));
    command.getParams("", "foo", ["hahaha"]).shouldEqual(["bar"]);
    command.getParams("", "includes", ["hahaha"]).shouldEqual(["hahaha"]);
}


void testObjectFile() {
    const obj = objectFile(SourceFile("path/to/src/foo.c"), Flags("-m64 -fPIC -O3"));
    obj.command.isDefaultCommand.shouldBeTrue;

    const build = Build(objectFile(SourceFile("path/to/src/foo.c"), Flags("-m64 -fPIC -O3")));
    build.targets[0].command.isDefaultCommand.shouldBeTrue;
}
