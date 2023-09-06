module tests.it.rules.json_build;

import tests.it;
import reggae.json_build;
import reggae.path: buildPath;
import std.file;
import std.stdio: File;

immutable linkJsonStr =
`
        [{"type": "fixed",
          "command": {"type": "link", "flags": ["-L-M"]},
          "outputs": ["myapp"],
          "dependencies": {
              "type": "dynamic",
              "func": "objectFiles",
              "src_dirs": ["src"],
              "exclude_dirs": [],
              "src_files": [],
              "exclude_files": [],
              "flags": ["-g"],
              "includes": ["src"],
              "string_imports": []},
          "implicits": {
              "type": "fixed",
              "targets": []}}]
`;


@("link with no files")
unittest {
    import reggae.config: options;
    const testPath = newTestDir;
    mkdir(buildPath(testPath, "src"));

    jsonToBuild(options, testPath, linkJsonStr).shouldEqual(
        Build(Target("myapp",
                     Command(CommandType.link, assocListT("flags", ["-L-M"]))))
    );
}
