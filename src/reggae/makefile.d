module reggae.makefile;

import reggae.build;
import reggae.range;
import std.conv;
import std.array;
import std.path;
import std.algorithm;


class Makefile {
    Build build;
    string projectPath;

    this(Build build) {
        this.build = build;
        this.projectPath = "";
    }

    this(Build build, string projectPath) {
        this.build = build;
        this.projectPath = projectPath.absolutePath;
    }

    string fileName() @safe pure nothrow const {
        return "Makefile";
    }

    string output() const {
        auto ret = text("all: ", build.targets[0].outputs[0], "\n");

        foreach(t; DepthFirst(build.targets[0])) {
            ret ~= text(t.outputs[0], ": ");
            ret ~= t.dependencyFiles(projectPath);
            ret ~= "\n";
            ret ~= "\t" ~ t.command(projectPath) ~ "\n";
        }

        return ret;
    }
}
