module tests.range;

import reggae;
import unit_threaded;
import std.array;


void testLeaf() {
    DepthFirst(Target("letarget")).array.shouldEqual([]);
}

void testOneDependencyLevel() {
    auto target = Target("letarget", "lecmdfoo bar other", [Target("foo"), Target("bar")]);
    auto depth = DepthFirst(target);
    depth.array.shouldEqual([target]);
}


void testTwoDependencyLevels() {
    auto fooObj = Target("foo.o", "gcc -c -o foo.o foo.c", [Target("foo.c")]);
    auto barObj = Target("bar.o", "gcc -c -o bar.o bar.c", [Target("bar.c")]);
    auto header = Target("hdr.h", "genhdr $in", [Target("hdr.i")]);
    auto impLeaf = Target("leaf");
    //implicit dependencies should show up, but only if they're not leaves
    auto target = Target("app", "gcc -o letarget foo.o bar.o", [fooObj, barObj], [header, impLeaf]);
    auto depth = DepthFirst(target);
    depth.array.shouldEqual([fooObj, barObj, header, target]);
}


void testProtocolExample() {
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
