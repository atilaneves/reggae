module tests.it.rules.json_build;

import tests.it;
import reggae.json_build;
import std.file;
import std.path;
import std.stdio: File;

immutable linkJsonStr =
`
        [{"type": "fixed",
          "command": {"type": "link", "flags": "-L-M"},
          "outputs": ["myapp"],
          "dependencies": {
              "type": "dynamic",
              "func": "objectFiles",
              "src_dirs": ["src"],
              "exclude_dirs": [],
              "src_files": [],
              "exclude_files": [],
              "flags": "-g",
              "includes": ["src"],
              "string_imports": []},
          "implicits": {
              "type": "fixed",
              "targets": []}}]
`;


@("link with no files")
unittest {
    const testPath = newTestDir;
    mkdir(buildPath(testPath, "src"));

    jsonToBuild(testPath, linkJsonStr).shouldEqual(
        Build(Target("myapp",
                     Command(CommandType.link, assocListT("flags", ["-L-M"]))))
    );
}

@("link with files")
unittest {
    import reggae.config;
    const testPath = newTestDir;
    setOptions(getOptions(["reggae", "-b", "ninja", "--per_module", "testPath"]));
    mkdir(buildPath(testPath, "src"));

    foreach(fileName; ["foo.d", "bar.d"]) {
        File(buildPath(testPath, "src", fileName), "w").writeln;
    }

    jsonToBuild(testPath, linkJsonStr).shouldEqual(
        Build(Target("myapp",
                     Command(CommandType.link, assocListT("flags", ["-L-M"])),
                     [Target("src/foo.o",
                             compileCommand("src/foo.d", "-g", [".", "src"]),
                             [Target("src/foo.d")]),
                      Target("src/bar.o",
                             compileCommand("src/bar.d", "-g", [".", "src"]),
                             [Target("src/bar.d")])]))
    );
}
