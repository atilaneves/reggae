module tests.json_build.rules;


import reggae;
import reggae.json_build;
import unit_threaded;


void testLink() {
    immutable jsonStr = `
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
              "targets": []}}]
`;

    const mainObj = Target("main.o", "dmd -I$project/src -c $in -of$out", Target("src/main.d"));
    const mathsObj = Target("maths.o", "dmd -c $in -of$out", Target("src/maths.d"));
    const app = link(ExeName("myapp"), [mainObj, mathsObj], Flags("-L-M"));

    jsonToBuild("", jsonStr).shouldEqual(
        Build(app));
}
