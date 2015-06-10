module tests.default_rules;


import reggae;
import unit_threaded;


void testNoDefaultRule() {
    Command("doStuff foo=bar").isDefaultCommand.shouldBeFalse;
}

void testGetRuleD() {
    const command = Command(Rule.compileD, assocList([assocEntry("foo", ["bar"])]));
    command.getRule.shouldEqual(Rule.compileD);
    command.isDefaultCommand.shouldBeTrue;
}

void testGetRuleCpp() {
    const command = Command(Rule.compileCpp, assocList([assocEntry("includes", ["src", "other"])]));
    command.getRule.shouldEqual(Rule.compileCpp);
    command.isDefaultCommand.shouldBeTrue;
}


void testValueWhenKeyNotFound() {
    const command = Command(Rule.compileD, assocList([assocEntry("foo", ["bar"])]));
    command.getParams("", "foo", ["hahaha"]).shouldEqual(["bar"]);
    command.getParams("", "includes", ["hahaha"]).shouldEqual(["hahaha"]);
}


void testObjectFile() {
    const obj = objectFile("path/to/src/foo.c", "-m64 -fPIC -O3");
    obj.command.isDefaultCommand.shouldBeTrue;

    const build = Build(objectFile("path/to/src/foo.c", "-m64 -fPIC -O3"));
    build.targets[0].command.isDefaultCommand.shouldBeTrue;
}
