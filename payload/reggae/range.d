module reggae.range;

import reggae.build;
import std.range;
import std.algorithm;
import std.conv;

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

    this(in Build build) pure nothrow @trusted {
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


struct UniqueDepthFirst2 {

    private const(Target)[] _targets;

    this(in Build build) pure nothrow {

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


    static assert(isInputRange!UniqueDepthFirst2);
}

alias TargetRef = long;

struct TargetWithRefs {
    const(string)[] outputs;
    const string command;
    const(TargetRef)[] dependencies;
    const(TargetRef)[] implicits;

    this(in string output, in string cmd = "",
         in TargetRef[] dependencies = [],
         in TargetRef[] implicits = []) pure nothrow {
        this([output], cmd, dependencies, implicits);
    }

    this(in string[] outputs, in string cmd = "",
         in TargetRef[] dependencies = [],
         in TargetRef[] implicits = []) pure nothrow {
        this.outputs = outputs;
        this.command = cmd;
        this.dependencies = dependencies.array;
        this.implicits = implicits;
    }
}


struct TargetConverter0 {
    private TargetWithRefs[] _targets;
    import std.stdio;
    void put(in Build build) @trusted {
        foreach(topTarget; build.targets) {
            foreach(target; DepthFirst(topTarget)) {
                writeln("Putting target ", target);
                put(target);
            }
        }
    }

    void put(in Target target) @trusted {
        import std.stdio;
        TargetRef[] newDependencies;
        foreach(dep; target.dependencies) {
            writeln("    dep: ", dep);
            if(!haveAlready(dep)) {
                writeln("        Don't have it yet, adding");
                _targets ~= TargetWithRefs(dep.outputs);
            } else {
                writeln("        Have this one already");
            }
            newDependencies ~= _targets.length - 1;
        }

        TargetRef[] newImplicits;
        foreach(imp; target.implicits) {
            writeln("    imp: ", imp);
            if(!haveAlready(imp)) {
                writeln("        Don't have it yet, adding");
                _targets ~= TargetWithRefs(imp.outputs);
            } else {
                writeln("        Have this one already");
            }
            newImplicits ~= _targets.length - 1;
        }


        _targets ~= TargetWithRefs(target.outputs, target.rawCmdString, newDependencies, newImplicits);
        writeln("targets: ", _targets, "\n");
    }

    TargetWithRefs[] targets() pure nothrow {
        return _targets;
    }

    TargetRef getRef(in TargetWithRefs target) const pure nothrow {
        return _targets.countUntil(target);
    }

    TargetRef getRef(in Target target) const pure {
        immutable index = _targets.countUntil(TargetWithRefs(target.outputs));
        if(index == -1) {
            immutable msg = () @trusted { return text("Dependencies for ", target, " were not filled in"); }();
            throw new Exception(msg);
        }
        return index;
    }

    bool haveAlready(in Target target) const pure nothrow {
        if(target.isLeaf) return _targets.canFind(TargetWithRefs(target.outputs));
        if(!chain(target.dependencies, target.implicits).all!(a => haveAlready(a))) return false;
        return true;
    }

    // TargetWithRefs convert(in Target target) const pure nothrow {
    //     if(target.isLeaf) return TargetWithRefs(target.outputs);
    //     const dependencies = target.dependencies.map!(a => getRef(a));
    //     const implicits = target.implicits.map!(a => getRef(a));
    //     return TargetWithRefs(target.outputs, target.rawCmdString, dependencies.array, implicits.array);
    // }
}


struct TargetConverter {
    TargetWithRefs convert(in Target target) pure {
        //leaves can always be converted
        if(target.isLeaf) return TargetWithRefs(target.outputs);

        TargetRef[] depRefs(in Target[] deps) @trusted {
            return deps.map!(a => convert(a)).map!(a => _targets.countUntil(a)).array;
        }
        const deps = depRefs(target.dependencies);
        const imps = depRefs(target.implicits);

        if(chain(deps, imps).any!(a => a == -1)) {
            immutable msg = () @trusted { return text("Could not find all dependency refs for ", target); }();
            throw new Exception(msg);
        }

        return TargetWithRefs(target.outputs, target.rawCmdString, deps, imps);
    }

    const (TargetWithRefs)[] targets() nothrow pure const {
        return _targets;
    }

    void put(in Target target) {
        foreach(dep; chain(target.dependencies, target.implicits)) {
            auto converted = convert(dep);
            if(!_targets.canFind(converted)) _targets ~= converted;
        }
        _targets ~= convert(target);
    }

private:

    TargetWithRefs[] _targets;
}
