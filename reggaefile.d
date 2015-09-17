import reggae;

version(minimal) {

    //flags have to name $project explicitly since these are low-level build definitions,
    //not the high level ones that do this automatically
    //This is a repetition in D of what's in minimal_bootstrap.sh
    enum flags = "-version=minimal -I$project/src -I$project/payload -J$project/payload/reggae";
    enum srcs = [Target("src/reggae/reggae_main.d"), Target("src/reggae/reggae.d"), Target("src/reggae/options.d"),
                Target("payload/reggae/types.d"), Target("payload/reggae/build.d"),
                Target("payload/reggae/config.d"), Target("payload/reggae/rules/common.d"),
                Target("payload/reggae/rules/defaults.d")];
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

    //the actual reggae binary
    //could also be dubConfigurationTarget(ExeName("reggae"), Configuration("executable"))
    //or use scriptlike to figure out dependencies itself
    alias main = dubDefaultTarget!(Flags("-g -debug -w"));

    //the unit test binary
    //since it depends on unit-threaded, must use a dub configuration
    alias ut = dubConfigurationTarget!(ExeName("ut"),
                                       Configuration("unittest"),
                                       Flags("-w -g -debug -cov"));

    enum cuke = Target.phony("cuke", "cd $project && cucumber", [main]);

    mixin build!(main, ut); //optional(cuke));
}
