import reggae;

version(minimal) {

    //flags have to name $project explicitly since these are low-level build definitions,
    //not the high level ones that do this automatically
    //This is a repetition in D of what's in minimal_bootstrap.sh
    enum flags = "-version=minimal -I$project/src -I$project/payload -J$project/payload/reggae";
    enum srcs = [
        Target("src/reggae/reggae_main.d"),
        Target("src/reggae/reggae.d"),
        Target("payload/reggae/options.d"),
        Target("payload/reggae/types.d"),
        Target("payload/reggae/build.d"),
        Target("payload/reggae/config.d"),
        Target("payload/reggae/rules/common.d"),
        Target("payload/reggae/rules/defaults.d"),
    ];
    enum cmd = "dmd -of$out " ~ flags ~ " $in";
    enum main = Target("bin/reggae", cmd, srcs);
    mixin build!(main);

    /* It's also possible for reggae to build itself with the build description below, but
      it's so ourobouros that it's always rebuilt. It works, though.

      alias main = scriptlike!(App(SourceFileName("src/reggae/reggae_main.d"), BinaryFileName("bin/reggae")),
                               Flags("-version=minimal"),
                               ImportPaths(["src", "payload"]),
                               StringImportPaths(["payload/reggae"]));
    */


} else {
    //fully featured build

    import std.typecons: Yes;

    //the actual reggae binary
    alias main = dubBuild!();

    //the unit test binary
    alias ut = dubTest!(CompilationMode.all, Yes.coverage);

    //the cucumber test target
    //enum cuke = Target.phony("cuke", "cd $project && cucumber", [main]);

    mixin build!(main, ut); //optional(cuke));
}
