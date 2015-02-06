module reggae;

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


Build getBuild(alias Module)() {
    return Build(leaf("foo.txt"));
}
