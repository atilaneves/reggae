module tests.ctaa;

import unit_threaded;
import reggae.ctaa;


void testEmpty() {
    auto aa = AssocList!(string, string)();
    aa.get("foo", "ohnoes").shouldEqual("ohnoes");
}

void testConversion() {
    auto aa = assocList([assocEntry("foo", "true")]);
    aa.get("foo", false).shouldBeTrue();
    aa.get("bar", false).shouldBeFalse();
    aa.get("bar", true).shouldBeTrue();
}

void testOpIndex() {
    static struct MyInt { int i; }
    auto aa = assocList([assocEntry("one", MyInt(1)), assocEntry("two", MyInt(2))]);
    aa["one"].shouldEqual(MyInt(1));
    aa["two"].shouldEqual(MyInt(2));
}


void testStringToStrings() {
    auto aa = assocList([assocEntry("includes", ["-I$project/headers"]),
                         assocEntry("flags", ["-m64", "-fPIC", "-O3"])]);
    aa["flags"].shouldEqual(["-m64", "-fPIC", "-O3"]);
    string[] emp;
    aa.get("flags", emp).shouldEqual(["-m64", "-fPIC", "-O3"]);

}
