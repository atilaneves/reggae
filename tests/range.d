module tests.range;

import reggae;
import unit_threaded;
import std.array;


void testDepFirstLeaf() {
    DepthFirst(Target("letarget")).array.shouldEqual([]);
}

void testDepthFirstOneDependencyLevel() {
    auto target = Target("letarget", "lecmdfoo bar other", [Target("foo"), Target("bar")]);
    auto depth = DepthFirst(target);
    depth.array.shouldEqual([target]);
}


void testDepthFirstTwoDependencyLevels() {
    auto fooObj = Target("foo.o", "gcc -c -o foo.o foo.c", [Target("foo.c")]);
    auto barObj = Target("bar.o", "gcc -c -o bar.o bar.c", [Target("bar.c")]);
    auto header = Target("hdr.h", "genhdr $in", [Target("hdr.i")]);
    auto impLeaf = Target("leaf");
    //implicit dependencies should show up, but only if they're not leaves
    auto target = Target("app", "gcc -o letarget foo.o bar.o", [fooObj, barObj], [header, impLeaf]);
    auto depth = DepthFirst(target);
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
    DepthFirst(app).array.shouldEqual(
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

void testDiamondDeps() {
    const obj1 = Target("obj1.o", "dmd -of$out -c $in", Target("src1.d"));
    const obj2 = Target("obj2.o", "dmd -of$out -c $in", Target("src2.d"));
    const fooLib = Target("$project/foo.so", "dmd -of$out $in", [obj1, obj2]);
    const symlink1 = Target("$project/weird/path/thingie1", "ln -sf $in $out", fooLib);
    const symlink2 = Target("$project/weird/path/thingie2", "ln -sf $in $out", fooLib);
    const build = Build(symlink1, symlink2); //defined by the mixin
    const targets = UniqueDepthFirst2(build).array;

    // targets.shouldEqual(
    //     [Target("objs/$project/weird/path/thingie1.objs/obj1.o", "dmd -of$out -c $in", Target("src1.d")),
    //      Target("objs/$project/weird/path/thingie1.objs/obj2.o", "dmd -of$out -c $in", Target("src2.d")),
    //      Target("$project/foo.so", "dmd -of$out $in",
    //             [Target("objs/$project/weird/path/thingie1.objs/obj1.o", "dmd -of$out -c $in", Target("src1.d")),
    //              Target("objs/$project/weird/path/thingie1.objs/obj2.o", "dmd -of$out -c $in", Target("src2.d"))]),
    //      symlink1, symlink2]);
    //targets.length.shouldEqual(5);
}

void testConvertLeaf() {
    auto converter = TargetConverter();
    converter.targets.array.shouldBeEmpty;

    converter.convert(Target("foo.d")).shouldEqual(TargetWithRefs("foo.d"));
    converter.targets.array.shouldBeEmpty;

    converter.convert(Target("bar.d")).shouldEqual(TargetWithRefs("bar.d"));
    converter.targets.array.shouldBeEmpty;

    converter.put(Target("foo.d"));
    converter.targets.array.shouldEqual([TargetWithRefs("foo.d")]);

    converter.put(Target("bar.d"));
    converter.targets.array.shouldEqual([TargetWithRefs("foo.d"), TargetWithRefs("bar.d")]);

}

void testConvertOneLevel() {
    auto converter = TargetConverter();
    const target = Target("foo.o", "dmd -of$out -c $in", [Target("foo.d")], [Target("hidden")]);
    //converter is empty, it can't find target's dependencies and therefore throws
    converter.convert(target).shouldThrow;
    converter.targets.array.shouldBeEmpty;

    converter.put(target);
    converter.convert(target).shouldEqual(TargetWithRefs("foo.o", "dmd -of$out -c $in", [0], [1]));

    converter.targets.array.shouldEqual(
        [TargetWithRefs("foo.d"), TargetWithRefs("hidden"),
         TargetWithRefs("foo.o", "dmd -of$out -c $in", [0], [1])]);
}

// void testConverterGetRefEmpty() {
//     auto converter = TargetConverter();
//     converter.getRef(Target("foo.d")).shouldThrow;
// }

// void testConverterGerRefLeaves() {
//     auto converter = TargetConverter();
//     const foo = Target("foo.d");
//     converter.put(foo);
//     converter.getRef(foo).shouldEqual(0);

//     const bar = Target("bar.d");
//     converter.getRef(bar).shouldThrow;

//     converter.put(bar);
//     converter.getRef(foo).shouldEqual(0);
//     converter.getRef(bar).shouldEqual(1);
//     converter.getRef(Target("baz.d")).shouldThrow;
// }

// void testConverterGetRefBranches() {
//     auto converter = TargetConverter();
//     const target = Target("foo.o", "dmd -of$out -c $in", [Target("foo.d")], [Target("hidden")]);
//     converter.put(target);
//     converter.getRef(Target("foo.d")).shouldEqual(0);
//     converter.getRef(Target("bar.d")).shouldEqual(1);
// }

// void testConvertLeaf() {
//     auto converter = TargetConverter();

//     const foo = Target("foo.d");
//     converter.put(foo);
//     converter.targets.array.shouldEqual([TargetWithRefs("foo.d")]);

//     const bar = Target("bar.d");
//     converter.put(bar);
//     converter.targets.array.shouldEqual([TargetWithRefs("foo.d"), TargetWithRefs("bar.d")]);

//     converter.getRef(foo).shouldEqual(0);
//     converter.getRef(bar).shouldEqual(1);
//     converter.getRef(Target("quux.d")).shouldEqual(-1);
// }

// void testConvertOneLevel() {
//     auto converter = TargetConverter();
//     const target = Target("foo.o", "dmd -of$out -c $in", [Target("foo.d")], [Target("hidden")]);
//     converter.put(target);
//     immutable srcRef = converter.getRef(Target("foo.d"));
//     immutable hiddenRef = converter.getRef(Target("hidden"));
//     converter.targets.array.shouldEqual(
//         [
//             TargetWithRefs("foo.d"),
//             TargetWithRefs("hidden"),
//             TargetWithRefs("foo.o", "dmd -of$out -c $in", [srcRef], [hiddenRef])
//             ]);

//     converter.haveAlready(target).shouldBeTrue;
//     converter.getRef(target).shouldEqual(2);
// }


// void testConvertDiamondDeps() {
//     const obj1 = Target("obj1.o", "dmd -of$out -c $in", Target("src1.d"));
//     const obj2 = Target("obj2.o", "dmd -of$out -c $in", Target("src2.d"));
//     const fooLib = Target("$project/foo.so", "dmd -of$out $in", [obj1, obj2]);
//     const symlink1 = Target("$project/weird/path/thingie1", "ln -sf $in $out", fooLib);
//     const symlink2 = Target("$project/weird/path/thingie2", "ln -sf $in $out", fooLib);
//     const build = Build(symlink1, symlink2); //defined by the mixin
//     auto converter = TargetConverter();
//     converter.put(build);
//     //converter.targets.array.length.shouldEqual(5);
//     converter.targets.array.shouldEqual(
//         [
//             TargetWithRefs("src1.d"),
//             TargetWithRefs("objs/$project/weird/path/thingie1.objs/obj1.o", "dmd -of$out -c $in", [0]),
//             TargetWithRefs("src2.d"),
//             TargetWithRefs("objs/$project/weird/path/thingie1.objs/obj2.o", "dmd -of$out -c $in", [2]),
//             TargetWithRefs("$project/foo.so", "dmd -of$out $in", [1, 3]),
//             TargetWithRefs("$project/weird/path/thingie1", "ln -sf $in $out", [4]),
//             TargetWithRefs("$project/weird/path/thingie2", "ln -sf $in $out", [4]),
//             ]);
// }
