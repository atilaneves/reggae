module tests.binary;

import reggae;
import unit_threaded;


bool fooCalled;
bool barCalled;

void resetCalls() { fooCalled = false; barCalled = false;}
void foo(in string[] inputs, in string[] outputs) {
    fooCalled = true;
}

void bar(in string[] inputs, in string[] outputs) {
    barCalled = true;
}

void testTargetSelection() {
    auto foo = Target("foo", &foo, Target("foo.d"));
    auto bar = Target("bar", &bar, Target("bar.d"));
    auto binary = Binary(Build(foo, bar), getOptions(["reggae", "--export"]));

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
    auto foo = Target("foo", &foo, Target("foo.d"));
    auto bar = Target("bar", &bar, Target("bar.d"));
    auto binary = Binary(Build(foo, bar), Options());
    binary.topLevelTargets(["foo"]).shouldEqual([foo]);
    binary.topLevelTargets(["bar"]).shouldEqual([bar]);
    binary.topLevelTargets([]).shouldEqual([foo, bar]);
    binary.topLevelTargets(["oops"]).shouldEqual([]);
}
