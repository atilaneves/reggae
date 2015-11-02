module tests.json_build.rules;


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
    const mainObj = Target("main.o", "dmd -I$project/src -c $in -of$out", Target("src/main.d"));
    const mathsObj = Target("maths.o", "dmd -c $in -of$out", Target("src/maths.d"));
    const app = link(ExeName("myapp"), [mainObj, mathsObj], Flags("-L-M"));

    jsonToBuild("", linkJsonString).shouldEqual(Build(app));
}


void testJsonToOptions() {
    import reggae.config: options;
    import std.json;

    auto oldOptions = options.dup;
    oldOptions.args = ["reggae", "-b", "ninja", "/path/to/my/project"];
    auto newOptions = jsonToOptions(oldOptions, parseJSON(linkJsonString));
    newOptions.cCompiler.shouldEqual("weirdcc");
    newOptions.cppCompiler.shouldEqual("g++");
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
                  {"dependencies": {
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
                            "targets": []}}]}}]},
                  "implicits": {
                      "type": "fixed",
                      "targets": []}}]
`;
}

void testJsonTargetConcatFixed() {
    const mainObj = Target("main.o", "dmd -I$project/src -c $in -of$out", Target("src/main.d"));
    const mathsObj = Target("maths.o", "dmd -c $in -of$out", Target("src/maths.d"));
    const app = link(ExeName("myapp"), [mainObj, mathsObj], Flags("-L-M"));
    jsonToBuild("", targetConcatFixedJsonStr).shouldEqual(Build(app));
}
