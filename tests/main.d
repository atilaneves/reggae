import unit_threaded;

int main(string[] args) {
    import unit_threaded.runner.runner: runTests;

    primeDubBuild;

    return args.runTests!(
        "tests.ut.by_package",
        "tests.ut.cpprules",
        "tests.ut.options",
        "tests.ut.serialisation",
        "tests.ut.realistic_build",
        "tests.ut.backend.binary",
        "tests.ut.backend.ninja",
        "tests.ut.backend.make",
        "tests.ut.simple_foo_reggaefile",
        "tests.ut.ninja",
        "tests.ut.simple_bar_reggaefile",
        "tests.ut.default_options",
        "tests.ut.json_build.rules",
        "tests.ut.json_build.simple",
        "tests.ut.code_command",
        "tests.ut.build",
        "tests.ut.default_rules",
        "tests.ut.rules.link",
        "tests.ut.rules.common",
        "tests.ut.range",
        "tests.ut.ctaa",
        "tests.ut.types",
        "tests.it.backend.binary",
        "tests.it.buildgen.arbitrary",
        "tests.it.buildgen.reggaefile_errors",
        "tests.it.buildgen.phony",
        "tests.it.buildgen.multiple_outputs",
        "tests.it.buildgen.export_",
        "tests.it.buildgen.optional",
        "tests.it.buildgen.backend_errors",
        "tests.it.buildgen.automatic_dependency",
        "tests.it.buildgen.implicits",
        "tests.it.buildgen.code_command",
        "tests.it.buildgen",
        "tests.it.buildgen.outputs_in_project_path",
        "tests.it.buildgen.two_builds_reggaefile",
        "tests.it.buildgen.empty_reggaefile",
        "tests.it",
        "tests.it.rules.scriptlike",
        "tests.it.rules.json_build",
        "tests.it.rules.cmake",
        "tests.it.rules.d_cmake_interop",
        "tests.it.runtime.lua",
        "tests.it.runtime.javascript",
        "tests.it.runtime.user_vars",
        "tests.it.runtime.error_messages",
        "tests.it.runtime.regressions",
        "tests.it.runtime.ruby",
        "tests.it.runtime.python",
        "tests.it.runtime",
        "tests.it.runtime.issues",
        "tests.it.runtime.dependencies",
        "tests.it.runtime.dub.proper",
        "tests.it.runtime.dub.dependencies",
        "tests.it.runtime.backend.binary",
    );
}

private void primeDubBuild() {
    import reggae.reggae: dubObjsDir;
    import tests.it.runtime: testRun;
    import std.file: write, exists, mkdirRecurse;
    import std.path: buildPath, dirName;
    import std.stdio: writeln;

    writeln("Priming...");
    scope(exit) writeln("Primed\n");

    const reggaefile = buildPath(dubObjsDir, "prime", "reggaefile.d");
    if(!reggaefile.dirName.exists)
        mkdirRecurse(reggaefile.dirName);

    write(
        reggaefile,
        q{
            import reggae;
            // mention dubPackage to trigger a runtime dub dependency
            mixin build!(Target.phony("foo", ""));
        }
    );

    testRun(
        [
            "reggae",
            "--dub-objs-dir=" ~ dubObjsDir,
            "-C" ~ reggaefile.dirName,
            reggaefile.dirName,
        ]
    );
}
