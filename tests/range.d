module tests.range;

import reggae;
import unit_threaded;
import std.array;


void testLeaf() {
    auto depth = DepthFirst(Target("letarget"));
    depth.array.shouldEqual([]);
}

void testOneDependencyLevel() {
    auto target = Target("letarget", [Target("foo"), Target("bar")], "lecmdfoo bar other");
    auto depth = DepthFirst(target);
    depth.array.shouldEqual([target]);
}


void testTwoDependencyLevels() {
    auto fooObj = Target("foo.o", [Target("foo.c")], "gcc -c -o foo.o foo.c");
    auto barObj = Target("bar.o", [Target("bar.c")], "gcc -c -o bar.o bar.c");
    auto target = Target("app", [fooObj, barObj], "gcc -o letarget foo.o bar.o");
    auto depth = DepthFirst(target);
    depth.array.shouldEqual([fooObj, barObj, target]);
}
