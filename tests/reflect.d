module tests.reflect;

import unit_threaded;
import reggae;


void testSimpleBuild() {
    {
        import tests.simple_foo_reggaefile;
        const build = getBuild!(tests.simple_foo_reggaefile);
        build().shouldEqual(Build(Target("foo.txt")));
    }
    {
        import tests.simple_bar_reggaefile;
        const build = getBuild!(tests.simple_bar_reggaefile);
        build().shouldEqual(Build(Target("bar.txt")));
    }
}

void testRealisticBuild() {
    const build = getBuild!"tests.realistic_build";
    build().shouldEqual(Build(Target("leapp",
                                     "dmd -ofleapp foo.o bar.o",
                                     [Target("foo.o", "dmd -c -offoo.o foo.d", [Target("foo.d")]),
                                      Target("bar.o", "dmd -c -ofbar.o bar.d", [Target("bar.d")])])));
}
