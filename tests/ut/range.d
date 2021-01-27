module tests.ut.range;

import reggae;
import unit_threaded;
import std.array;


@("depthFirst Leaf") unittest {
    depthFirst(Target("letarget")).array.shouldBeEmpty;
}

@("depthFirst one dependency level") unittest {
    auto target = Target("letarget", "lecmdfoo bar other", [Target("foo"), Target("bar")]);
    auto depth = depthFirst(target);
    depth.array.shouldEqual([target]);
}


@("depthFirst two dependency levels") unittest {
    auto fooObj = Target("foo.o", "gcc -c -o foo.o foo.c", [Target("foo.c")]);
    auto barObj = Target("bar.o", "gcc -c -o bar.o bar.c", [Target("bar.c")]);
    auto header = Target("hdr.h", "genhdr $in", [Target("hdr.i")]);
    auto impLeaf = Target("leaf");
    //implicit dependencies should show up, but only if they're not leaves
    auto target = Target("app", "gcc -o letarget foo.o bar.o", [fooObj, barObj], [header, impLeaf]);
    auto depth = depthFirst(target);
    depth.array.shouldEqual([fooObj, barObj, header, target]);
}


@("depthFirst protocol example") unittest {
    auto protoSrcs = Target([`$builddir/gen/protocol.c`, `$builddir/gen/protocol.h`],
                             `./compiler $in`,
                             [Target(`protocol.proto`)]);
    auto protoObj = Target(`$builddir/bin/protocol.o`,
                            `gcc -o $out -c $builddir/gen/protocol.c`,
                            [], [protoSrcs]);
    auto protoD = Target(`$builddir/gen/protocol.d`,
                          `echo "extern(C) " > $out; cat $builddir/gen/protocol.h >> $out`,
                          [], [protoSrcs]);
    auto app = Target(`app`,
                       `dmd -of$out $in`,
                       [Target(`src/main.d`), protoObj, protoD]);
    depthFirst(app).array.shouldEqual(
        [protoSrcs, protoObj, protoSrcs, protoD, app]);
}


@("ByDepthLevel leaf") unittest {
    ByDepthLevel(Target("letarget")).array.shouldBeEmpty;
}


@("ByDepthLevel one level") unittest {
    auto target = Target("letarget", "lecmdfoo bar other", [Target("foo"), Target("bar")]);
    auto byLevel = ByDepthLevel(target);
    byLevel.array.shouldEqual([[target]]);
}

@("ByDepthLevel two dependency levels") unittest {
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
            [barObj, fooObj, header], //level 1
            [target], //level 0
            ]);
}

@("Leaves empty") unittest {
    Leaves(Target("leaf")).array.shouldEqual([Target("leaf")]);
}


@("Leaves two levels") unittest {
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
