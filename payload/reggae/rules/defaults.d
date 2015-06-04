module reggae.rules.defaults;


import std.algorithm: find, canFind, splitter, startsWith;
import std.array: replace, array;


private immutable defaultRules = ["_dcompile", "_ccompile", "_cppcompile", "_dlink"];

private bool isDefaultRule(in string command) @safe pure nothrow {
    return defaultRules.canFind(command);
}

private string getRule(in string command) @safe pure {
    return command.splitter.front;
}

bool isDefaultCommand(in string command) @safe pure {
    return isDefaultRule(command.getRule);
}

string getDefaultRule(in string command) @safe pure {
    immutable rule = command.getRule;
    if(!isDefaultRule(rule)) {
        throw new Exception("Cannot get defaultRule from " ~ command);
    }

    return rule;
}


string[] getDefaultRuleParams(in string command, in string key) @safe pure {
    return getDefaultRuleParams(command, key, false);
}


string[] getDefaultRuleParams(in string command, in string key, string[] ifNotFound) @safe pure {
    return getDefaultRuleParams(command, key, true, ifNotFound);
}


//@trusted because of replace
private string[] getDefaultRuleParams(in string command, in string key,
                                      bool useIfNotFound, string[] ifNotFound = []) @trusted pure {
    import std.conv: text;

    auto parts = command.splitter;
    immutable cmd = parts.front;
    if(!isDefaultRule(cmd)) {
        throw new Exception("Cannot get defaultRule from " ~ command);
    }

    auto fromParamPart = parts.find!(a => a.startsWith(key ~ "="));
    if(fromParamPart.empty) {
        if(useIfNotFound) {
            return ifNotFound;
        } else {
            throw new Exception ("Cannot get default rule from " ~ command);
        }
    }

    auto paramPart = fromParamPart.front;
    auto removeKey = paramPart.replace(key ~ "=", "");

    return removeKey.splitter(",").array;
}
