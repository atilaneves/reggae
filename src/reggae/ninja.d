module reggae.ninja;


import reggae.build;
import std.array;
import std.range;
import std.algorithm;


struct NinjaEntry {
    string buildLine;
    string[] paramLines;
}


struct Ninja {
    void addTarget(in Target target) @safe pure nothrow {
        if(_targets.canFind(target)) return;
        _targets ~= target;
    }

    NinjaEntry[] buildEntries() nothrow const {
        NinjaEntry[] entries;
        foreach(const target; _targets) {
            const cmd = targetCommand(target);
            entries ~= NinjaEntry("build " ~ target.outputs[0] ~ ": " ~ cmd ~ " " ~ target.dependencyFiles);
        }
        return entries;
    }

    NinjaEntry[] ruleEntries() pure nothrow const {
        NinjaEntry[] entries;
        foreach(const target; _targets) {
            const cmd = targetCommand(target);
            entries ~= NinjaEntry("rule " ~ cmd,
                                  ["  command = " ~ cmd ~ " $in $out"]);
        }
        return entries;
    }


private:
    const(Target)[] _targets;
}

//@trusted because of splitter
private string targetCommand(in Target target) @trusted pure nothrow {
    return target.command.splitter(" ").front.sanitizeCmd;
}

//@trusted because of replace
private string sanitizeCmd(in string cmd) @trusted pure nothrow {
    import std.path;
    //only handles c++ compilers so far...
    return cmd.baseName.replace("+", "p");
}


// import reggae.build;
// import std.range: chain, isInputRange;
// import std.algorithm;
// import std.array;
// import std.path;


// string[] addToNinjaRules(in Target target, ref string[] rules) {
//     const parametrisedCmdElems = target.dependencyFiles.splitter(" ").array;
//     const fromCommand = parametrisedCmdElems[1 .. $];
//     const fromIn = fromCommand.find("$in");
//     const fromOut = fromCommand.find("$out");
//     const fromFirst = fromIn.length > fromOut.length ? fromIn : fromOut;
//     const fromLast = fromIn.length > fromOut.length ? fromOut : fromIn;

//     assertCanFindFirstAndLast(fromFirst, fromLast, target, parametrisedCmdElems);

//     const before = fromCommand[0 .. (fromCommand.length - fromFirst.length)];
//     const betweenUpperBound = fromFirst.length - fromLast.length - 1;
//     const between = betweenUpperBound >= 1 ? fromFirst[1 .. 1 + betweenUpperBound] : [];
//     const after = fromLast.empty ? [] : fromLast[1..$];
//     const fromMf = fromCommand.find("-MF");
//     assert(fromMf.length == 0 || fromMf.length > 1);

//     const cmd = target.command.splitter(" ").front;
//     auto cmdElems = [cmd];

//     if(!before.empty) cmdElems ~= "$before";
//     cmdElems ~= fromFirst.front;

//     if(!between.empty) cmdElems ~= "$between";
//     cmdElems ~= fromLast.front;

//     if(!after.empty) cmdElems ~= "$after";
//     const cmdLine = "  command = " ~ cmdElems.join(" ");

//     auto cmdSanitized = cmd.sanitizeCmd;
//     auto ruleFirstLine = "rule " ~ cmdSanitized;
//     auto ruleOtherLines = [cmdLine];

//     if(!fromMf.empty) {
//         ruleOtherLines ~= "  deps = gcc";
//         ruleOtherLines ~= "  depfile = $DEPFILE";
//     }

//     if(haveToAddRule(rules, cmdSanitized, ruleFirstLine, ruleOtherLines)) {
//         auto rule = ruleFirstLine ~ ruleOtherLines ~ "";
//         if(cmd.startsWith("flex")) rule = rule.map!(a => a.replace("$out", "-o$out")).array;
//         rules ~= rule;
//     }

//     auto buildLines = ["build " ~ target.outputs[0] ~ ": " ~ cmdSanitized ~ " " ~
//                        target.dependencyFiles];

//     const realBefore = cmd.startsWith("flex") ?
//         before.filter!(a => a != "-o").join(" ") :
//         before.join(" ");

//     if(!before.empty) buildLines ~= "  before = " ~ realBefore;
//     if(!between.empty) buildLines ~= "  between = " ~ between.join(" ");
//     if(!after.empty) buildLines ~= "  after = " ~ after.join(" ");
//     if(!fromMf.empty) buildLines ~= "  DEPFILE = " ~ fromMf[1];

//     return buildLines ~ "";
// }


// private void assertCanFindFirstAndLast(T, U)(in T fromFirst, in U fromLast,
//                                              in Target target,
//                                              in string[] parametrisedCmdElems)
//     @safe if(isInputRange!T && isInputRange!U) {

//     () @trusted {
//         import std.conv: text;
//         const msg = text("\n\ntarget:\n", target.outputs[0],
//                          "\n\ndeps:\n", target.dependencyFiles,
//                          "\n\ncommand:\n", target.command,
//                          "\n\nparametrisedCmdElems:\n", parametrisedCmdElems);
//         assert(!fromFirst.empty, "fromFirst empty!" ~ msg);
//         assert(!fromLast.empty, "fromLast empty!" ~ msg);

//         assert(!fromFirst.empty, "fromFirst empty!");
//         assert(!fromLast.empty, "fromLast empty!");
//     }();
// }


// private bool haveToAddRule(in string[] ruleLines,
//                            ref string cmdSanitized,
//                            ref string ruleFirstLine,
//                            in string[] ruleOtherLines) nothrow {
//     static int counter = 1;

//     alias rule = string[];
//     auto getRulesWithSameHeader(in string[] ruleLines, in string cmdSanitized) @trusted pure nothrow {
//         const(rule)[] rules;

//         auto fromRuleLine = ruleLines.find!(a => a.canFind("rule " ~ cmdSanitized));
//         while(!fromRuleLine.empty) {
//             const fromNextEmpty = fromRuleLine.find("");
//             const diffInSize = fromRuleLine.length - fromNextEmpty.length;
//             assert(diffInSize > 1);
//             rules ~= fromRuleLine.array[1 .. diffInSize];
//             fromRuleLine.popFront;
//             fromRuleLine = fromRuleLine.find!(a => a.canFind("rule " ~ cmdSanitized));
//         }
//         return rules;
//     }

//     const rulesWithSameHeader = getRulesWithSameHeader(ruleLines, cmdSanitized);
//     if(rulesWithSameHeader.empty) return true;
//     const haveSameLines = rulesWithSameHeader.canFind(ruleOtherLines);

//     //unfortunate but necessary side-effects
//     if(haveSameLines) { //have to use the same cmd_num as the previous one
//         const fromOtherLines = ruleLines.find(ruleOtherLines);

//         assert(!fromOtherLines.empty);
//         assert(ruleLines.length - fromOtherLines.length > 0);
//         const ruleHeader = ruleLines[ruleLines.length - fromOtherLines.length - 1];
//         cmdSanitized = ruleHeader.splitter(" ").array[1];
//     } else {

//         import std.conv: to;
//         const suffix = "_" ~ (++counter).to!string;
//         cmdSanitized ~= suffix;
//         ruleFirstLine ~= suffix;
//     }

//     return !haveSameLines;
// }

// private string sanitizeCmd(in string cmd) @trusted pure nothrow {
//     //only handles c++ compilers so far...
//     return cmd.baseName.replace("+", "p");
// }
