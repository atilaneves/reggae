module tests.binary;

import reggae;
import unit_threaded;


void testDep() {
    immutable depFileLines = [
        "objs/calc.objs/src/cpp/maths.o: \\",
        "/home/aalvesne/coding/d/reggae/tmp/aruba/mixproj/src/cpp/maths.cpp \\",
        "/home/aalvesne/coding/d/reggae/tmp/aruba/mixproj/headers/maths.hpp\n"];
    dependenciesFromFile(depFileLines).shouldEqual(
        [ "/home/aalvesne/coding/d/reggae/tmp/aruba/mixproj/src/cpp/maths.cpp",
          "/home/aalvesne/coding/d/reggae/tmp/aruba/mixproj/headers/maths.hpp"]);
}

class FooException: Exception {
    this(string msg = "") { super(msg); }
}

class BarException: Exception {
    this(string msg = "") { super(msg); }
}

bool fooCalled;
bool barCalled;

void resetCalls() { fooCalled = false; barCalled = false;}
void foo(in string[] inputs, in string[] outputs) {
    fooCalled = true;
}

void bar(in string[] inputs, in string[] outputs) {
    barCalled = true;
}

@HiddenTest
void testTargetSelection() {
    const foo = Target("foo", &foo, Target("foo.d"));
    const bar = Target("bar", &bar, Target("bar.d"));
    const binary = Binary(Build(foo, bar), "/path/to");

    {
        scope(exit) resetCalls;
        binary.run(["prog"]);
        fooCalled.shouldBeTrue;
        barCalled.shouldBeTrue;
    }

    {
        scope(exit) resetCalls;
        binary.run(["prog", "foo", "bar"]);
        fooCalled.shouldBeTrue;
        barCalled.shouldBeTrue;
    }

    {
        scope(exit) resetCalls;
        binary.run(["prog", "foo"]);
        fooCalled.shouldBeTrue;
        barCalled.shouldBeFalse;
    }

    {
        scope(exit) resetCalls;
        binary.run(["prog", "bar"]);
        fooCalled.shouldBeFalse;
        barCalled.shouldBeTrue;
    }

    {
        scope(exit) resetCalls;
        binary.run(["prog", "nonexistent"]).shouldThrow;
        fooCalled.shouldBeFalse;
        barCalled.shouldBeFalse;
    }
}

void testTopLevelTargets() {
    import core.exception: RangeError;
    const foo = Target("foo", &foo, Target("foo.d"));
    const bar = Target("bar", &bar, Target("bar.d"));
    const binary = Binary(Build(foo, bar), "/path/to");
    binary.topLevelTargets(["prog", "foo"]).shouldEqual([foo]);
    binary.topLevelTargets(["prog", "bar"]).shouldEqual([bar]);
    binary.topLevelTargets(["prog"]).shouldEqual([foo, bar]);
    binary.topLevelTargets([]).shouldThrow!RangeError;
    binary.topLevelTargets(["prog", "oops"]).shouldEqual([]);
}
