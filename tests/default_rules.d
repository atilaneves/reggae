module tests.default_rules;


import reggae;
import unit_threaded;


void testNoDefaultRule() {
    Command("doStuff foo=bar").getRule.shouldEqual("doStuff");
    Command("_foo foo=bar").getRule.shouldEqual("_foo");
    Command("doStuff foo=bar").isDefaultCommand.shouldBeFalse;
}

void testGetDefaultRule() {
    Command("_dcompile foo=bar").getRule.shouldEqual("_dcompile");
    Command("_ccompile foo=bar").getRule.shouldEqual("_ccompile");
    Command("_cppcompile foo=bar").getRule.shouldEqual("_cppcompile");
    Command("_link foo=bar").getRule.shouldEqual("_link");
    Command("_link foo=bar").isDefaultCommand.shouldBeTrue;
}


void testValueWhenKeyNotFound() {
    immutable command = Command("_dcompile foo=bar");
    command.getParams("", "foo", ["hahaha"]).shouldEqual(["bar"]);
    command.getParams("", "includes", ["hahaha"]).shouldEqual(["hahaha"]);
}
