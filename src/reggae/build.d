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
    string[] command;

    this(string output, in Target dependency, string[] command) {
        this(output, [dependency], command);
    }

    this(string output, in Target[] dependencies, string[] command) {
        this.outputs = [output];
        this.dependencies = dependencies;
        this.command = command;
    }
}


Target leaf(in string str) {
    return Target(str, null, null);
}
