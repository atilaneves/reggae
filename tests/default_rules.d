module tests.default_rules;


import reggae;
import unit_threaded;


void testNoDefaultRule() {
    Command("doStuff foo=bar").getDefaultRule.shouldThrow;
    Command("_foo foo=bar").getDefaultRule.shouldThrow;
}

void testGetDefaultRule() {
    Command("_dcompile foo=bar").getDefaultRule.shouldEqual("_dcompile");
    Command("_ccompile foo=bar").getDefaultRule.shouldEqual("_ccompile");
    Command("_cppcompile foo=bar").getDefaultRule.shouldEqual("_cppcompile");
    Command("_link foo=bar").getDefaultRule.shouldEqual("_link");
}


void testValueWhenKeyNotFound() {
    immutable command = Command("_dcompile foo=bar");
    command.getDefaultRuleParams("", "foo", ["hahaha"]).shouldEqual(["bar"]);
    command.getDefaultRuleParams("", "includes", ["hahaha"]).shouldEqual(["hahaha"]);
}
