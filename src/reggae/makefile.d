module reggae.makefile;

import reggae.build;
import reggae.range;
import reggae.rules;
import std.conv;
import std.array;
import std.path;
import std.algorithm;


struct Makefile {
    Build build;
    string projectPath;

    this(Build build) @safe pure {
        this.build = build;
        this.projectPath = "";
    }

    this(Build build, string projectPath) @safe pure {
        this.build = build;
        this.projectPath = projectPath.absolutePath;
    }

    string fileName() @safe pure nothrow const {
        return "Makefile";
    }

    string output() @safe const {
        auto ret = text("all: ", build.targets[0].outputs[0], "\n");

        foreach(t; DepthFirst(build.targets[0])) {
            ret ~= text(t.outputs[0], ": ");
            ret ~= t.dependencyFiles(projectPath);
            immutable implicitFiles = t.implicitFiles(projectPath);
            if(!implicitFiles.empty) ret ~= " " ~ t.implicitFiles(projectPath);
            ret ~= "\n";
            ret ~= "\t";
            immutable rawCmdLine = t.inOutCommand(projectPath);
            if(rawCmdLine.isDefaultCommand) {
                ret ~= command(t, rawCmdLine);
            } else {
                ret ~= t.command(projectPath);
            }
            ret ~= "\n";
        }

        return ret;
    }

    string command(in Target target, in string rawCmdLine) @safe const {
        immutable dCompiler = "dmd";
        immutable cppCompiler = "g++";
        immutable cCompiler = "gcc";
        immutable rule = rawCmdLine.getDefaultRule;

        if(rule == "_dcompile") {
            immutable flags = rawCmdLine.getDefaultRuleParams("flags", []).join(" ");
            immutable includes = rawCmdLine.getDefaultRuleParams("includes", []).join(" ");
            immutable stringImports = rawCmdLine.getDefaultRuleParams("stringImports", []).join(" ");
            immutable depfile = target.outputs[0] ~ ".d";
            return ["./dcompile", dCompiler, flags, includes, stringImports, target.outputs[0],
                    target.dependencyFiles(projectPath), depfile].join(" ");
        } else if(rule == "_cppcompile") {
            immutable flags = rawCmdLine.getDefaultRuleParams("flags", []).join(" ");
            immutable includes = rawCmdLine.getDefaultRuleParams("includes", []).join(" ");
            immutable depfile = target.outputs[0] ~ ".d";
            return [cppCompiler, flags, includes, "-MMD", "-MT", target.outputs[0],
                    "-MF", depfile, "-o", target.outputs[0], "-c",
                    target.dependencyFiles(projectPath)].join(" ");
        } else if(rule == "_ccompile") {
            immutable flags = rawCmdLine.getDefaultRuleParams("flags", []).join(" ");
            immutable includes = rawCmdLine.getDefaultRuleParams("includes", []).join(" ");
            immutable depfile = target.outputs[0] ~ ".d";
            return [cCompiler, flags, includes, "-MMD", "-MT", target.outputs[0],
                    "-MF", depfile, "-o", target.outputs[0], "-c",
                    target.dependencyFiles(projectPath)].join(" ");
        } else if(rule == "_dlink") {
            return [dCompiler, "-of" ~ target.outputs[0], target.dependencyFiles(projectPath)].join(" ");
        } else {
            throw new Exception("Unknown Makefile default rule " ~ rule);
        }
    }
}
