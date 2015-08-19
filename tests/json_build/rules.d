module tests.json_build.rules;


import reggae;
import reggae.json_build;
import unit_threaded;


void testLink() {
    immutable jsonStr = `
        [{"command": {"type": "link", "flags": "-L-M"},
          "outputs": ["myapp"],
          "dependencies":
          [{"command": {"type": "shell", "cmd":
                        "dmd -I$project/src -c $in -of$out"},
            "outputs": ["main.o"],
            "dependencies": [{"command": {}, "outputs": ["src/main.d"],
                              "dependencies": [], "implicits": []}],
            "implicits": []},
           {"command": {"type": "shell", "cmd":
                        "dmd -c $in -of$out"},
            "outputs": ["maths.o"],
            "dependencies": [{"command": {}, "outputs": ["src/maths.d"],
                              "dependencies": [], "implicits": []}],
            "implicits": []}],
          "implicits": []}]
`;

    const mainObj = Target("main.o", "dmd -I$project/src -c $in -of$out", Target("src/main.d"));
    const mathsObj = Target("maths.o", "dmd -c $in -of$out", Target("src/maths.d"));
    const app = link(ExeName("myapp"), [mainObj, mathsObj], Flags("-L-M"));

    jsonToBuild(jsonStr).shouldEqual(
        Build(app));
}
