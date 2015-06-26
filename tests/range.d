module tests.range;

import reggae;
import unit_threaded;
import std.array;


void testDepFirstLeaf() {
    depthFirst(Target("letarget")).array.shouldEqual([]);
}

void testDepthFirstOneDependencyLevel() {
    auto target = Target("letarget", "lecmdfoo bar other", [Target("foo"), Target("bar")]);
    auto depth = depthFirst(target);
    depth.array.shouldEqual([target]);
}


void testDepthFirstTwoDependencyLevels() {
    auto fooObj = Target("foo.o", "gcc -c -o foo.o foo.c", [Target("foo.c")]);
    auto barObj = Target("bar.o", "gcc -c -o bar.o bar.c", [Target("bar.c")]);
    auto header = Target("hdr.h", "genhdr $in", [Target("hdr.i")]);
    auto impLeaf = Target("leaf");
    //implicit dependencies should show up, but only if they're not leaves
    auto target = Target("app", "gcc -o letarget foo.o bar.o", [fooObj, barObj], [header, impLeaf]);
    auto depth = depthFirst(target);
    depth.array.shouldEqual([fooObj, barObj, header, target]);
}


void testDepthFirstProtocolExample() {
    const protoSrcs = Target([`$builddir/gen/protocol.c`, `$builddir/gen/protocol.h`],
                             `./compiler $in`,
                             [Target(`protocol.proto`)]);
    const protoObj = Target(`$builddir/bin/protocol.o`,
                            `gcc -o $out -c $builddir/gen/protocol.c`,
                            [], [protoSrcs]);
    const protoD = Target(`$builddir/gen/protocol.d`,
                          `echo "extern(C) " > $out; cat $builddir/gen/protocol.h >> $out`,
                          [], [protoSrcs]);
    const app = Target(`app`,
                       `dmd -of$out $in`,
                       [Target(`src/main.d`), protoObj, protoD]);
    depthFirst(app).array.shouldEqual(
        [protoSrcs, protoObj, protoSrcs, protoD, app]);
}


void testByDepthLevelLeaf() {
    ByDepthLevel(Target("letarget")).array.shouldEqual([]);
}


void testByDepthLevelOneLevel() {
    const target = Target("letarget", "lecmdfoo bar other", [Target("foo"), Target("bar")]);
    auto byLevel = ByDepthLevel(target);
    byLevel.array.shouldEqual([[target]]);
}

void testByDepthLevelTwoDependencyLevels() {
    auto fooC = Target("foo.c");
    auto barC = Target("bar.c");
    auto fooObj = Target("foo.o", "gcc -c -o foo.o foo.c", [fooC]);
    auto barObj = Target("bar.o", "gcc -c -o bar.o bar.c", [barC]);
    auto hdrI = Target("hdr.i");
    auto header = Target("hdr.h", "genhdr $in", [hdrI]);
    auto impLeaf = Target("leaf");

    //implicit dependencies should show up, but only if they're not leaves
    auto target = Target("app",
                         "gcc -o letarget foo.o bar.o",
                         [fooObj, barObj],
                         [header, impLeaf]);

    auto rng = ByDepthLevel(target);

    //reverse order should show up: first level 1, then level 0
    //level 2 doesn't show up since they're all leaves (fooC, barC, hdrI)
    rng.array.shouldEqual(
        [
            [fooObj, barObj, header], //level 1
            [target], //level 0
            ]);
}

void testLeavesEmpty() {
    Leaves(Target("leaf")).array.shouldEqual([Target("leaf")]);
}


void testLeavesTwoLevels() {
    auto fooC = Target("foo.c");
    auto barC = Target("bar.c");
    auto fooObj = Target("foo.o", "gcc -c -o foo.o foo.c", [fooC]);
    auto barObj = Target("bar.o", "gcc -c -o bar.o bar.c", [barC]);
    auto hdrI = Target("hdr.i");
    auto header = Target("hdr.h", "genhdr $in", [hdrI]);
    auto impLeaf = Target("leaf");

    //implicit dependencies should show up, but only if they're not leaves
    auto target = Target("app",
                         "gcc -o letarget foo.o bar.o",
                         [fooObj, barObj],
                         [header, impLeaf]);

    Leaves(target).array.shouldEqual([fooC, barC, hdrI, impLeaf]);

}


void testConvertLeaf() {
    auto graph = Graph();
    graph.targets.array.shouldBeEmpty;

    const foo = Target("foo.d");
    graph.convert(foo).shouldEqual(TargetWithRefs(foo));
    graph.targets.array.shouldBeEmpty;

    const bar = Target("bar.d");
    graph.convert(bar).shouldEqual(TargetWithRefs(bar));
    graph.targets.array.shouldBeEmpty;

    graph.put(foo);
    graph.targets.array.shouldEqual([TargetWithRefs(foo)]);

    graph.put(bar);
    graph.targets.array.shouldEqual([TargetWithRefs(foo), TargetWithRefs(bar)]);

}

void testConvertOneLevel() {
    auto graph = Graph();
    const foo = Target("foo.d");
    const hidden = Target("hidden");
    const target = Target("foo.o", "dmd -of$out -c $in", [foo], [hidden]);
    //graph is empty, it can't find target's dependencies and therefore throws
    graph.convert(target).shouldThrow;
    graph.targets.array.shouldBeEmpty;

    graph.put(target);
    graph.convert(target).shouldEqual(TargetWithRefs(target, [0], [1]));

    graph.targets.array.shouldEqual(
        [TargetWithRefs(foo),
         TargetWithRefs(hidden),
         TargetWithRefs(target, [graph.getRef(foo)], [graph.getRef(hidden)])]);

    graph.target(target).dependencies.shouldEqual([foo]);
    graph.target(target).implicits.shouldEqual([hidden]);
}

private struct DiamondDepsBuild {
    Target src1;
    Target src2;
    Target obj1;
    Target obj2;
    Target fooLib;
    Target symlink1;
    Target symlink2;
}

DiamondDepsBuild getDiamondDeps() {
    const src1 = Target("src1.d");
    const src2 = Target("src2.d");
    const obj1 = Target("obj1.o", "dmd -of$out -c $in", src1);
    const obj2 = Target("obj2.o", "dmd -of$out -c $in", src2);
    const fooLib = Target("$project/foo.so", "dmd -of$out $in", [obj1, obj2]);
    const symlink1 = Target("$project/weird/path/thingie1", "ln -sf $in $out", fooLib);
    const symlink2 = Target("$project/weird/path/thingie2", "ln -sf $in $out", fooLib);
    return DiamondDepsBuild(src1, src2, obj1, obj2, fooLib, symlink1, symlink2);
}

void testConvertDiamondDepsNoBuildStruct() {
    auto deps = getDiamondDeps();
    auto graph = Graph([deps.symlink1,deps.symlink2]);

    graph.targets.array.shouldEqual(
        [
            TargetWithRefs(deps.src1),
            TargetWithRefs(deps.obj1, [0]),
            TargetWithRefs(deps.src2),
            TargetWithRefs(deps.obj2, [2]),
            TargetWithRefs(deps.fooLib, [1, 3]),
            TargetWithRefs(deps.symlink1, [4]),
            TargetWithRefs(deps.symlink2, [4]),
            ]);

    graph.convert(deps.symlink1).shouldEqual(TargetWithRefs(deps.symlink1, [graph.getRef(deps.fooLib)]));
}


@ShouldFail
void testConvertDiamondDeps() {
    const deps = getDiamondDeps();
    const build = Build(deps.symlink1, deps.symlink2); //defined by the mixin
    const graph = Graph(build);

    graph.targets.array.shouldEqual(
        [
            TargetWithRefs(deps.src1),
            TargetWithRefs(deps.obj1, [0]),
            TargetWithRefs(deps.src2),
            TargetWithRefs(deps.obj2, [2]),
            TargetWithRefs(deps.fooLib, [1, 3]),
            TargetWithRefs(deps.symlink1, [4]),
            TargetWithRefs(deps.symlink2, [4]),
            ]);
}
