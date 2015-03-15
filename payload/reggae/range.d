module reggae.range;

import reggae.build;
import std.range;
import std.algorithm;

struct DepthFirst {
    const(Target)[] targets;

    this(in Target target) @safe pure nothrow {
        this.targets = depthFirstTargets(target);
    }

    const(Target)[] depthFirstTargets(in Target target) @safe pure nothrow {
        //if leaf, return
        if(target.isLeaf) return target.command is null ? [] : [target];

        //if not, add ourselves to the end to get depth-first
        return reduce!((a, b) => a ~ depthFirstTargets(b))(typeof(return).init, target.dependencies) ~
            reduce!((a, b) => a ~ depthFirstTargets(b))(typeof(return).init, target.implicits) ~
            target;
    }

    auto front() @safe pure nothrow {
        return targets.front;
    }

    void popFront() @safe pure nothrow {
        targets.popFront;
    }

    bool empty() @safe pure nothrow {
        return targets.empty;
    }

    static assert(isInputRange!DepthFirst);
}
