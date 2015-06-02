module tests.ctaa;

import unit_threaded;
import reggae.ctaa;


void testEmpty() {
    auto aa = AssocList();
    aa.get("foo", "ohnoes").shouldEqual("ohnoes");
}

void testConversion() {
    auto aa = AssocList([AssocEntry("foo", "true")]);
    aa.get("foo", false).shouldBeTrue();
    aa.get("bar", false).shouldBeFalse();
    aa.get("bar", true).shouldBeTrue();
}

void testOpIndex() {
    static struct MyInt { int i; }
    auto aa = assocList([assocEntry("one", MyInt(1)), assocEntry("two", MyInt(2))]);
    aa["one"].shouldEqual(MyInt(1));
    aa["two"].shouldEqual(MyInt(1));
}
