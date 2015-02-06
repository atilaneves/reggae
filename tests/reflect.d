module tests.reflect;

import unit_threaded;
import reggae;


void testSimpleBuild() {
    import tests.simple_reggaefile;
    const build = getBuild!(tests.simple_reggaefile);
    build.shouldEqual(Build(leaf("foo.txt")));
}
