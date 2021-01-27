module tests.ut.reflect;

import unit_threaded;
import reggae;


@("Simple build") unittest {
    {
        import tests.ut.simple_foo_reggaefile;
        const build = getBuild!(tests.ut.simple_foo_reggaefile);
        build().shouldEqual(Build(Target("foo.txt")));
    }
    {
        import tests.ut.simple_bar_reggaefile;
        const build = getBuild!(tests.ut.simple_bar_reggaefile);
        build().shouldEqual(Build(Target("bar.txt")));
    }
}

@("Realistic build") unittest {
    const build = getBuild!"tests.ut.realistic_build";
    build().shouldEqual(Build(Target("leapp",
                                     "dmd -ofleapp foo.o bar.o",
                                     [Target("foo.o", "dmd -c -offoo.o foo.d", [Target("foo.d")]),
                                      Target("bar.o", "dmd -c -ofbar.o bar.d", [Target("bar.d")])])));
}
