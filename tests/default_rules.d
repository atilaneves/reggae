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

void testGetDefaultRuleParams() {
    immutable command = Command("_dcompile foo=bar includes=boo,looloo,bearhugs");
    command.getDefaultRuleParams("", "foo").shouldEqual(["bar"]);
    command.getDefaultRuleParams("", "includes").shouldEqual(["boo", "looloo", "bearhugs"]);
    command.getDefaultRuleParams("", "nonexistent").shouldThrow!Exception;

    Command("_madeup includes=boo,bar").getDefaultRuleParams("", "includes").shouldThrow!Exception;
}

void testValueWhenKeyNotFound() {
    immutable command = Command("_dcompile foo=bar");
    command.getDefaultRuleParams("", "foo", ["hahaha"]).shouldEqual(["bar"]);
    command.getDefaultRuleParams("", "includes", ["hahaha"]).shouldEqual(["hahaha"]);
}
