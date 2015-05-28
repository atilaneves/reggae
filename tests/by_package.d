module tests.by_package;

import unit_threaded;
import reggae.sorting;

void testIsSamePackage() {
    "/path/to/foo.d".isInSamePackageAs("/path/to/bar.d").shouldBeTrue;
    "/path/to/foo.d".isInSamePackageAs("/path/to/baz.d").shouldBeTrue;
    "/path/to/foo.d".isInSamePackageAs("/oops/ugh/boo.d").shouldBeFalse;
}
