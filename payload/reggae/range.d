module reggae.range;

import reggae.build;
import std.range;
import std.algorithm;
import std.conv;
import std.exception;

@safe:

enum isTargetLike(T) = is(typeof(() {
    auto target = T.init;
    auto deps = target.dependencies;
    auto imps = target.implicits;
    if(target.isLeaf) {}
    string cmd = target.expandCommand;
    cmd = target.expandCommand("");
}));

static assert(isTargetLike!Target);

struct DepthFirst(T) if(isTargetLike!T) {
    const(Target)[] targets;

    this(in T target) pure nothrow {
        this.targets = depthFirstTargets(target);
    }

    const(Target)[] depthFirstTargets(in T target) pure nothrow {
        //if leaf, return
        if(target.isLeaf) return target.expandCommand is null ? [] : [target];

        //if not, add ourselves to the end to get depth-first
        return reduce!((a, b) => a ~ depthFirstTargets(b))(typeof(return).init, target.dependencies) ~
            reduce!((a, b) => a ~ depthFirstTargets(b))(typeof(return).init, target.implicits) ~
            target;
    }

    T front() pure nothrow {
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

auto depthFirst(T)(in T target) pure nothrow {
    return DepthFirst!T(target);
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

    this(in Build build) pure nothrow @trusted {
        _targets = build.targets.
            map!(a => depthFirst(a)).
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


//a reference to a target. The reggae API uses values, but DAGs need references
alias TargetRef = long;

//a wrapper for each distinct target so that we can deal with reference semantics
struct TargetWithRefs {
    Target target;
    const(TargetRef)[] dependencies;
    const(TargetRef)[] implicits;
}

import std.stdio;


//a converter from Target to TargetWithRefs
struct Graph {

    this(Build build) pure {
        this(build.targets);
    }

    this(in Target[] topLevelTargets) pure {
        foreach(topTarget; topLevelTargets) {
            foreach(target; depthFirst(topTarget)) {
                put(target);
            }
        }
    }

    TargetWithRefs convert(in Target target) pure const {
        //leaves can always be converted
        if(target.isLeaf) return TargetWithRefs(target);

        immutable(TargetRef)[] depRefs(in Target[] deps) @trusted {
            return deps.map!(a => getRef(a)).array.assumeUnique;
        }

        immutable deps = depRefs(target.dependencies);
        immutable imps = depRefs(target.implicits);

        if(chain(deps, imps).canFind(-1)) {
            immutable msg = () @trusted { return text("Could not find all dependency refs for ", target); }();
            throw new Exception(msg);
        }

        return TargetWithRefs(target, deps, imps);
    }

    const (TargetWithRefs)[] targets() nothrow pure const {
        return _targets;
    }

    void put(in Target target) @trusted pure {
        foreach(t; chain(target.dependencies, target.implicits, [target])) {
            putIfNotAlreadyHere(t);
        }
    }

    TargetRef getRef(in Target target) pure const {
        return _targets.countUntil(convert(target));
    }

    TargetWrapper target(in Target target) pure const {
        return TargetWrapper(convert(target), _targets);
    }

private:

    TargetWithRefs[] _targets;

    void putIfNotAlreadyHere(in Target target) pure {
        auto converted = convert(target);
        if(!_targets.canFind(converted)) _targets ~= converted;
    }
}


struct TargetWrapper {
    TargetWithRefs targetWithRefs;
    const TargetWithRefs[] targets;

    const(Target)[] dependencies() const pure nothrow {
           return subTargets(targetWithRefs.dependencies);
    }

    const(Target)[] implicits() const pure nothrow {
        return subTargets(targetWithRefs.implicits);
    }

    auto expandCommand(in string projectPath = "") const pure nothrow {
        return targetWithRefs.target.expandCommand(projectPath);
    }

    auto isLeaf() const pure nothrow {
        return targetWithRefs.target.isLeaf;
    }

private:

    //@trusted because of .array
    const(Target)[] subTargets(in TargetRef[] refs) const pure nothrow @trusted {
        return refs.map!(a => targets[a].target).array;
    }

    static assert(isTargetLike!TargetWrapper);
}
