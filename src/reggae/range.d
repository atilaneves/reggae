module reggae.range;

import reggae.build;
import std.range;
import std.algorithm;

struct DepthFirst {
    const(Target)[] targets;

    this(Target target) {
        this.targets = depthFirstTargets(target);
    }

    const(Target)[] depthFirstTargets(in Target target) {
        //if leaf, return
        if(target.dependencies is null) return target.command is null ? [] : [target];

        //if not, add ourselves to the end to get depth-first
        return reduce!((a, b) => a ~ depthFirstTargets(b))(typeof(return).init, target.dependencies) ~
            target;
    }

    auto front() @safe pure nothrow {
        return targets.front;
    }

    void popFront() @safe nothrow {
        targets.popFront;
    }

    bool empty() @safe pure nothrow {
        return targets.empty;
    }

    static assert(isInputRange!DepthFirst);
}
