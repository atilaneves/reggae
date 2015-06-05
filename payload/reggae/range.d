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

    this(in Target target) {//pure nothrow {
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

    private const(Target)[][] sortTargets(in Target target) {//pure nothrow {
        if(target.isLeaf) return [];

        const(Target)[][] targets = [[target]];
        rec(0, [target], targets);
        return targets.retro.array;
    }

    private void rec(int level, in Target[] targets, ref const(Target)[][] soFar) @trusted {//pure nothrow {
        auto notLeaves = targets.
            map!(a => chain(a.dependencies, a.implicits)). //get all dependencies
            flatten. //flatten into a regular range
            filter!(a => !a.isLeaf). //don't care about leaves
            array;
        if(notLeaves.empty) return;
        soFar ~= notLeaves;
        rec(level + 1, notLeaves, soFar);
    }

    static assert(isInputRange!ByDepthLevel);
}


auto flatten(R)(R range) {
    alias rangeType = ElementType!R;
    alias T = ElementType!rangeType;
    T[] res;
    foreach(x; range) res ~= x.array;
    return res;
}
