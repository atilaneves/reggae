module tests.it.dub;

import unit_threaded;

@("describe")
@Tags(["dub"])
unittest {

    import std.string: join;
    import std.algorithm: find;
    import std.format: format;
    import std.process;
    import std.array: replace;

    const string[string] env = null;
    Config config = Config.none;
    size_t maxOutput = size_t.max;

    with(immutable Sandbox()) {
        writeFile("dub.sdl",
                  [
                      `name "foo"`,
                      `targetType "executable"`,
                      `dependency "bar" path="bar"`,
                      `versions "lefoo"`
                  ].join("\n"));

        writeFile("source/app.d",
                  [
                      `void main() {`,
                      `    import bar;`,
                      `    lebar;`,
                      `}`,
                  ]);

        writeFile("bar/dub.sdl",
                  [
                      `name "bar"`,
                      `targetType "library"`,
                      ].join("\n"));


        writeFile("bar/source/bar.d",
                  [
                      `module bar;`,
                      `void lebar() {}`,
                  ]);

        const ret = execute(["dub", "describe"], env, config, maxOutput, testPath);
        if(ret.status != 0)
            throw new Exception("Could not call dub describe:\n" ~ ret.output);

        ret.output.find("{").replace("/", `\/`).shouldBeSameJsonAs(
            import("foobar.json").format(testPath, testPath, testPath, testPath, testPath,
                                         testPath, testPath, testPath, testPath, testPath, testPath));
    }
}
