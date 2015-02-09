module reggae.build;


struct Build {
    const(Target)[] targets;

    this(in Target target) {
        this([target]);
    }

    this(in Target[] targets) {
        this.targets = targets;
    }
}

struct Target {
    string[] outputs;
    const(Target)[] dependencies;
    string command;

    this(string output) {
        this(output, null, null);
    }

    this(string output, in Target dependency, string command) {
        this([output], [dependency], command);
    }

    this(string output, in Target[] dependencies, string command) {
        this([output], dependencies, command);
    }

    this(string[] outputs, in Target[] dependencies, string command) {
        import std.string: replace;
        import std.algorithm: map, join;

        this.outputs = outputs;
        this.dependencies = dependencies;
        auto replaceIn = command.replace("$in", dependencies.map!(a => a.outputs.join(" ")).join(" "));
        this.command = replaceIn.replace("$out", outputs.join(" "));
    }
}


Target leaf(in string str) {
    return Target(str, null, null);
}
