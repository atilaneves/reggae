module tests.ut.rules.common;


import reggae;
import unit_threaded;


@("objFileName")
unittest {
    import reggae.path: deabsolutePath;
    import std.path: stripExtension, defaultExtension, isRooted;
    import std.array: replace;

    "foo.d".objFileName.should == "foo.o";
    "foo._.d".objFileName.should == "foo._.o";
}
