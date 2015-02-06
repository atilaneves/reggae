module reggae.makefile;

import reggae.build;
import reggae.range;
import std.conv;
import std.array;

class Makefile {
    Build build;

    this(Build build) {
        this.build = build;
    }

    string fileName() @safe pure nothrow const {
        return "Makefile";
    }

    string output() const {
        auto ret = text("all: ", build.targets[0].outputs[0], "\n");
        foreach(t; DepthFirst(build.targets[0])) {
            ret ~= text(t.outputs[0], ": ");
            foreach(i, dep; t.dependencies) { //join doesn't do const
                ret ~= text(dep.outputs[0]);
                if(i != t.dependencies.length - 1) ret ~= " ";
            }
            ret ~= "\n";
            ret ~= "\t" ~ join(t.command, " ") ~ "\n";
        }

        return ret;
    }
}
