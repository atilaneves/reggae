module tests.range;

import reggae;
import unit_threaded;
import std.array;


void testLeaf() {
    auto depth = DepthFirst(Target("letarget"));
    depth.array.shouldEqual([]);
}

void testOneDependencyLevel() {
    auto target = Target("letarget", "lecmdfoo bar other", [Target("foo"), Target("bar")]);
    auto depth = DepthFirst(target);
    depth.array.shouldEqual([target]);
}


void testTwoDependencyLevels() {
    auto fooObj = Target("foo.o", "gcc -c -o foo.o foo.c", [Target("foo.c")]);
    auto barObj = Target("bar.o", "gcc -c -o bar.o bar.c", [Target("bar.c")]);
    auto target = Target("app", "gcc -o letarget foo.o bar.o", [fooObj, barObj]);
    auto depth = DepthFirst(target);
    depth.array.shouldEqual([fooObj, barObj, target]);
}
