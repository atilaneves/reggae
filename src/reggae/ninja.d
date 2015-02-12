module reggae.ninja;


import reggae.build;
import reggae.range;
import std.array;
import std.range;
import std.algorithm;
import std.exception: enforce;
import std.conv: text;
import std.string: strip;

struct NinjaEntry {
    string mainLine;
    string[] paramLines;
    string toString() @safe pure nothrow const {
        return (mainLine ~ paramLines.map!(a => "  " ~ a).array).join("\n");
    }
}


struct Ninja {
    NinjaEntry[] buildEntries;
    NinjaEntry[] ruleEntries;

    this(Build build, in string projectPath = "") {
        _build = build;
        _projectPath = projectPath;
        stuff();
    }

    void stuff() {
        foreach(target; DepthFirst(_build.targets[0])) {
            import std.regex;
            auto reg = regex(`^[^ ]+ +(.*?)(\$in|\$out)(.*?)(\$in|\$out)(.*?)$`);
            auto rawCmdLine = target.inOutCommand(_projectPath);
            auto mat = rawCmdLine.match(reg);
            enforce(!mat.captures.empty, text("Command: ", rawCmdLine, ", Captures: ", mat.captures));
            immutable before = mat.captures[1].strip;
            immutable first = mat.captures[2];
            immutable between = mat.captures[3].strip;
            immutable last  = mat.captures[4];
            immutable after = mat.captures[5].strip;

            immutable ruleCmdLine = getRuleCommandLine(target, before, first, between, last, after);
            bool haveToAdd;
            immutable ruleName = getRuleName(targetCommand(target), ruleCmdLine, haveToAdd);
            immutable buildLine = "build " ~ target.outputs[0] ~ ": " ~ ruleName ~
                " " ~ target.dependencyFiles(_projectPath);
            string[] buildParamLines;
            if(!before.empty)  buildParamLines ~= "before = "  ~ before;
            if(!between.empty) buildParamLines ~= "between = " ~ between;
            if(!after.empty)   buildParamLines ~= "after = "   ~ after;

            buildEntries ~= NinjaEntry(buildLine, buildParamLines);

            if(haveToAdd) {
                ruleEntries ~= NinjaEntry("rule " ~ ruleName,
                                          [ruleCmdLine]);
            }
        }
    }

    string getRuleCommandLine(in Target target, in string before, in string first, in string between,
                              in string last, in string after) {
        auto cmdLine = ["command", "=", targetRawCommand(target)];
        if(!before.empty) cmdLine ~= "$before";
        cmdLine ~= first;
        if(!between.empty) cmdLine ~= "$between";
        cmdLine ~= last;
        if(!after.empty) cmdLine ~= "$after";
        return cmdLine.join(" ");
    }

    //Ninja operates on rules, not commands. Since this is supposed to work with
    //generic build systems, the same command can appear with different parameter
    //ordering. The first time we create a rule with the same name as the command.
    //The subsequent times, if any, we append a number to the command to create
    //a new rule
    string getRuleName(in string cmd, in string ruleCmdLine, out bool haveToAdd) {
        immutable ruleMainLine = "rule " ~ cmd;
        //don't have a rule for this cmd yet, return just the cmd
        if(!ruleEntries.canFind!(a => a.mainLine == ruleMainLine)) {
            haveToAdd = true;
            return cmd;
        }

        //so we have a rule for this already. Need to check if the command line
        //is the same

        //same cmd: either matches exactly or is cmd_{number}
        auto isSameCmd = (in NinjaEntry entry) {
            bool sameMainLine = entry.mainLine.startsWith(ruleMainLine) &&
            (entry.mainLine == ruleMainLine || entry.mainLine[ruleMainLine.length] == '_');
            bool sameCmdLine = entry.paramLines == [ruleCmdLine];
            return sameMainLine && sameCmdLine;
        };

        auto rulesWithSameCmd = ruleEntries.filter!isSameCmd;
        assert(rulesWithSameCmd.empty || rulesWithSameCmd.array.length == 1);

        //found a sule with the same cmd and paramLines
        if(!rulesWithSameCmd.empty) return rulesWithSameCmd.front.mainLine.replace("rule ", "");

        //if we got here then it's the first time we see "cmd" with a new
        //ruleCmdLine, so we add it
        haveToAdd = true;
        import std.conv: to;
        static int counter = 1;
        return cmd ~ "_" ~ (++counter).to!string;
    }

    NinjaEntry[] buildEntries1() const {
        NinjaEntry[] entries;
        foreach(target; DepthFirst(_build.targets[0])) {
            import std.regex;
            auto reg = regex(`^[^ ]+ +(.*?)(\$in|\$out)(.*?)(\$in|\$out)(.*?)$`);
            auto rawCmdLine = target.inOutCommand;
            auto mat = rawCmdLine.match(reg);
            enforce(!mat.captures.empty, text("Command: ", rawCmdLine, ", Captures: ", mat.captures));
            immutable before = mat.captures[1].strip;
            immutable between = mat.captures[3].strip;
            immutable after = mat.captures[5].strip;
            immutable buildLine = "build " ~ target.outputs[0] ~ ": " ~ targetCommand(target) ~
                " " ~ target.dependencyFiles(_projectPath);
            string[] paramLines;
            if(!before.empty)  paramLines ~= "before = "  ~ before;
            if(!between.empty) paramLines ~= "between = " ~ between;
            if(!after.empty)   paramLines ~= "after = "   ~ after;

            entries ~= NinjaEntry(buildLine, paramLines);
        }
        return entries;
    }

    NinjaEntry[] ruleEntries1() const {
        NinjaEntry[] entries;
        foreach(target; DepthFirst(_build.targets[0])) {
            import std.regex;
            auto reg = regex(`^[^ ]+ +(.*?)(\$in|\$out)(.*?)(\$in|\$out)(.*?)$`);
            auto mat = target.inOutCommand.match(reg);
            enforce(!mat.captures.empty, text("Command: ", target.inOutCommand, " Captures: ", mat.captures));
            immutable before = mat.captures[1].strip;
            immutable between = mat.captures[3].strip;
            immutable after = mat.captures[5].strip;
            immutable first = mat.captures[2];
            immutable last  = mat.captures[4];
            auto cmdLine = ["command", "=", targetRawCommand(target)];
            if(!before.empty) cmdLine ~= "$before";
            cmdLine ~= first;
            if(!between.empty) cmdLine ~= "$between";
            cmdLine ~= last;
            if(!after.empty) cmdLine ~= "$after";
            entries  ~= NinjaEntry("rule " ~ targetCommand(target),
                                   [cmdLine.join(" ")]);
        }
        return entries;
    }


private:
    Build _build;
    string _projectPath;
}

//@trusted because of splitter
private string targetCommand(in Target target) @trusted pure nothrow {
    return target.command.splitter(" ").front.sanitizeCmd;
}

//@trusted because of splitter
private string targetRawCommand(in Target target) @trusted pure nothrow {
    return target.command.splitter(" ").front;
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
