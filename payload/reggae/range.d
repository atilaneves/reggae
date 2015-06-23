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
        if(target.isLeaf) return target.expandCommand is null ? [] : [target];

        //if not, add ourselves to the end to get depth-first
        return reduce!((a, b) => a ~ depthFirstTargets(b))(typeof(return).init, target.dependencies) ~
            reduce!((a, b) => a ~ depthFirstTargets(b))(typeof(return).init, target.implicits) ~
            target;
    }

    Target front() pure nothrow {
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
        if(target.isLeaf) return [];

        const(Target)[][] targets = [[target]];
        rec(0, [target], targets);
        return targets.retro.array;
    }

    private void rec(int level, in Target[] targets, ref const(Target)[][] soFar) @trusted pure nothrow {
        const notLeaves = targets.
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

struct Leaves {
    this(in Target target) pure nothrow {
        recurse(target);
    }

    Target front() pure nothrow {
        return targets.front;
    }

    void popFront() pure nothrow {
        targets.popFront;
    }

    bool empty() pure nothrow {
        return targets.empty;
    }


private:

    const(Target)[] targets;

    void recurse(in Target target) pure nothrow {
        if(target.isLeaf) {
            targets ~= target;
            return;
        }

        foreach(dep; target.dependencies ~ target.implicits) {
            if(dep.isLeaf) {
                targets ~= dep;
            } else {
                recurse(dep);
            }
        }
    }

    static assert(isInputRange!Leaves);
}


//TODO: a non-allocating version with no arrays
auto flatten(R)(R range) @trusted pure nothrow {
    alias rangeType = ElementType!R;
    alias T = ElementType!rangeType;
    T[] res;
    foreach(x; range) res ~= x.array;
    return res;
}

//TODO: a non-allocating version with no arrays
auto noSortUniq(R)(R range) if(isInputRange!R) {
    ElementType!R[] ret;
    foreach(elt; range) {
        if(!ret.canFind(elt)) ret ~= elt;
    }
    return ret;
}

//removes duplicate targets from the build, presents a depth-first interface
//per top-level target
struct UniqueDepthFirst {
    Build build;
    private const(Target)[] _targets;

    this(in Build build) pure nothrow {
        _targets = build.targets.
            map!(a => DepthFirst(a)).
            flatten.
            noSortUniq.
            array;
    }

    Target front() pure nothrow {
        return _targets.front;
    }

    void popFront() pure nothrow {
        _targets.popFront;
    }

    bool empty() pure nothrow {
        return _targets.empty;
    }

    static assert(isInputRange!UniqueDepthFirst);
}
