module tests.sandbox;

// Keep this module independent of reggae: ordering its TLS constructor with
// reggae's compiler registration would introduce a constructor cycle.
static this() {
    import core.runtime: Runtime;
    import std.algorithm: canFind;
    import std.file: exists;
    import std.path: absolutePath, buildNormalizedPath, buildPath;
    import unit_threaded.integration: Sandbox;

    if(Runtime.args.canFind("--rerun-check"))
        return;

    // Rerun children clear unit-threaded's default sandbox directory.
    foreach(root; [".", ".."]) {
        if(buildPath(root, "dub.json").exists) {
            Sandbox.setPath(buildPath(root.absolutePath.buildNormalizedPath, "tmp", "sandboxes"));
            return;
        }
    }
    assert(false, "Cannot locate reggae test sandbox root");
}
