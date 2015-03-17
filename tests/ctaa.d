module tests.ctaa;

import unit_threaded;
import reggae.ctaa;


void testEmpty() {
    auto aa = AssocList();
    aa.get("foo", "ohnoes").shouldEqual("ohnoes");
    aa["foo"] = "bar";
    aa.get("foo", "ohnoes").shouldEqual("bar");
    aa["foo"].shouldEqual("bar");
}
