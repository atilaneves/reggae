module reggae.build;


struct Build {
    Target target;
}

struct Target {
    string[] outputs;
    Target[] dependencies;
    string[] command;

    this(string output, Target[] dependencies, string[] command) {
        this.outputs = [output];
        this.dependencies = dependencies;
        this.command = command;
    }
}


Target leaf(in string str) {
    return Target(str, null, null);
}
