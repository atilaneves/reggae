module tests.reflect;

import unit_threaded;
import reggae;


void testSimpleBuild() {
    {
        import tests.simple_foo_reggaefile;
        const build = getBuild!(tests.simple_foo_reggaefile);
        build.shouldEqual (Build(leaf("foo.txt")));
    }
    {
        import tests.simple_bar_reggaefile;
        const build = getBuild!(tests.simple_bar_reggaefile);
        build.shouldEqual (Build(leaf("bar.txt")));
    }

}
