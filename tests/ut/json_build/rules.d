module tests.ut.json_build.rules;


import reggae;
import reggae.json_build;
import unit_threaded;


string linkJsonString() @safe pure nothrow {
    return `
        [{"type": "fixed",
          "command": {"type": "link", "flags": "-L-M"},
          "outputs": ["myapp"],
          "dependencies": {
              "type": "fixed",
              "targets":
              [{"type": "fixed",
                "command": {"type": "shell", "cmd":
                            "dmd -I$project/src -c $in -of$out"},
                "outputs": ["main.o"],
                "dependencies": {"type": "fixed",
                                 "targets": [
                                     {"type": "fixed",
                                      "command": {}, "outputs": ["src/main.d"],
                                      "dependencies": {
                                          "type": "fixed",
                                          "targets": []},
                                      "implicits": {
                                          "type": "fixed",
                                          "targets": []}}]},
                "implicits": {
                    "type": "fixed",
                    "targets": []}},
               {"type": "fixed",
                "command": {"type": "shell", "cmd":
                            "dmd -c $in -of$out"},
                "outputs": ["maths.o"],
                "dependencies": {
                    "type": "fixed",
                    "targets": [
                        {"type": "fixed",
                         "command": {}, "outputs": ["src/maths.d"],
                         "dependencies": {
                             "type": "fixed",
                             "targets": []},
                         "implicits": {
                             "type": "fixed",
                             "targets": []}}]},
                "implicits": {
                    "type": "fixed",
                    "targets": []}}]},
          "implicits": {
              "type": "fixed",
              "targets": []}},
        {"type": "defaultOptions",
         "cCompiler": "weirdcc",
         "oldNinja": true
        }]
`;
}


void testLink() {
    auto mainObj = Target("main.o", "dmd -I$project/src -c $in -of$out", Target("src/main.d"));
    auto mathsObj = Target("maths.o", "dmd -c $in -of$out", Target("src/maths.d"));
    auto app = link(ExeName("myapp"), [mainObj, mathsObj], Flags("-L-M"));

    jsonToBuild("", linkJsonString).shouldEqual(Build(app));
}


@("jsonToOptions version0")
unittest {
    import reggae.config: gDefaultOptions;
    import std.json;

    auto oldOptions = gDefaultOptions.dup;
    oldOptions.args = ["reggae", "-b", "ninja", "/path/to/my/project"];
    auto newOptions = jsonToOptions(oldOptions, parseJSON(linkJsonString));
    newOptions.cCompiler.shouldEqual("weirdcc");
    newOptions.cppCompiler.shouldEqual("g++");
}

private string toVersion1(in string jsonString, in string dependencies = `[]`) {
    return `{"version": 1, "defaultOptions": {"cCompiler": "huh"}, "dependencies": ` ~ dependencies ~ `, "build": ` ~ jsonString ~ `}`;
}

@("jsonToOptions version1")
unittest {
    import reggae.config: gDefaultOptions;
    import std.json;

    auto oldOptions = gDefaultOptions.dup;
    oldOptions.args = ["reggae", "-b", "ninja", "/path/to/my/project"];
    immutable jsonString = linkJsonString.toVersion1;
    auto newOptions = jsonToOptions(oldOptions, parseJSON(jsonString));
    newOptions.cCompiler.shouldEqual("huh");
    newOptions.cppCompiler.shouldEqual("g++");
    newOptions.oldNinja.shouldBeFalse;
}

@("jsonToOptions with dependencies")
unittest {
    import std.json;
    import std.file;
    import reggae.path: buildPath;

    version(Windows)
        enum projectPath = "C:/path/to/my/project";
    else
        enum projectPath = "/path/to/my/project";

    Options defaultOptions;
    defaultOptions.args = ["reggae", "-b", "ninja", projectPath];
    immutable jsonString = linkJsonString.toVersion1(`["/path/to/foo.py", "/other/path/bar.py"]`);
    auto options = jsonToOptions(defaultOptions, parseJSON(jsonString));
    options.reggaeFileDependencies.shouldEqual(
        [thisExePath,
         buildPath(projectPath, "reggaefile.d"),
         "/path/to/foo.py",
         "/other/path/bar.py"]);
}


string targetConcatFixedJsonStr() @safe pure nothrow {
    return `
      [{"type": "fixed",
          "command": {"type": "link", "flags": "-L-M"},
          "outputs": ["myapp"],
          "dependencies": {
              "type": "dynamic",
              "func": "targetConcat",
              "dependencies": [
                  {
                      "type": "fixed",
                      "targets":
                      [{"type": "fixed",
                        "command": {"type": "shell",
                                    "cmd": "dmd -I$project/src -c $in -of$out"},
                        "outputs": ["main.o"],
                        "dependencies": {"type": "fixed",
                                         "targets": [
                                             {"type": "fixed",
                                              "command": {}, "outputs": ["src/main.d"],
                                              "dependencies": {
                                                  "type": "fixed",
                                                  "targets": []},
                                              "implicits": {
                                                  "type": "fixed",
                                                  "targets": []}}]},
                        "implicits": {
                            "type": "fixed",
                            "targets": []}},
                       {"type": "fixed",
                        "command": {"type": "shell", "cmd":
                                    "dmd -c $in -of$out"},
                        "outputs": ["maths.o"],
                        "dependencies": {
                            "type": "fixed",
                            "targets": [
                                {"type": "fixed",
                                 "command": {}, "outputs": ["src/maths.d"],
                                 "dependencies": {
                                     "type": "fixed",
                                     "targets": []},
                                 "implicits": {
                                     "type": "fixed",
                                     "targets": []}}]},
                        "implicits": {
                            "type": "fixed",
                            "targets": []}}]}]},
                  "implicits": {
                      "type": "fixed",
                      "targets": []}}]
`;
}

void testJsonTargetConcatFixed() {
    auto mainObj = Target("main.o", "dmd -I$project/src -c $in -of$out", Target("src/main.d"));
    auto mathsObj = Target("maths.o", "dmd -c $in -of$out", Target("src/maths.d"));
    auto app = link(ExeName("myapp"), [mainObj, mathsObj], Flags("-L-M"));
    jsonToBuild("", targetConcatFixedJsonStr).shouldEqual(Build(app));
}
