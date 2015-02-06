module tests.reflect;

import unit_threaded;
import reggae;


void testSimpleBuild() {
    {
        import tests.simple_foo_reggaefile;
        const build = getBuild!(tests.simple_foo_reggaefile);
        build.shouldEqual(Build(leaf("foo.txt")));
    }
    {
        import tests.simple_bar_reggaefile;
        const build = getBuild!(tests.simple_bar_reggaefile);
        build.shouldEqual(Build(leaf("bar.txt")));
    }
}

void testRealisticBuild() {
    const build = getBuild!"tests.realistic_build";
    build.shouldEqual(Build(Target("leapp",
                                   [Target("foo.o", [leaf("foo.d")], ["dmd", "-c", "-offoo.o", "foo.d"]),
                                    Target("bar.o", [leaf("bar.d")], ["dmd", "-c", "-ofbar.o", "bar.d"])],
                                   ["dmd", "-ofleapp", "foo.o", "bar.o"])));
}
