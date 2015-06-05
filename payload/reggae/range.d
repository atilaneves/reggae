module reggae.range;

import reggae.build;
import std.range;
import std.algorithm;

@safe:

struct DepthFirst {
    const(Target)[] targets;

    this(in Target target) pure nothrow {
        this.targets = depthFirstTargets(target);
    }

    const(Target)[] depthFirstTargets(in Target target) pure nothrow {
        //if leaf, return
        if(target.isLeaf) return target.command is null ? [] : [target];

        //if not, add ourselves to the end to get depth-first
        return reduce!((a, b) => a ~ depthFirstTargets(b))(typeof(return).init, target.dependencies) ~
            reduce!((a, b) => a ~ depthFirstTargets(b))(typeof(return).init, target.implicits) ~
            target;
    }

    auto front() pure nothrow {
        return targets.front;
    }

    void popFront() pure nothrow {
        targets.popFront;
    }

    bool empty() pure nothrow {
        return targets.empty;
    }

    static assert(isInputRange!DepthFirst);
}


struct ByDepthLevel {
    const(Target)[][] targets;

    this(in Target target) pure nothrow {
        this.targets = sortTargets(target);
    }

    auto front() pure nothrow {
        return targets.front;
    }

    void popFront() pure nothrow {
        targets.popFront;
    }

    bool empty() pure nothrow {
        return targets.empty;
    }

    private const(Target)[][] sortTargets(in Target target) pure nothrow {
        return target.isLeaf ? [] : [[target]];
    }

    static assert(isInputRange!ByDepthLevel);
}
