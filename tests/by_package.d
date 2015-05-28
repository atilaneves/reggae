module tests.by_package;


import unit_threaded;
import reggae.sorting;



void testByPackage() {
    auto files = ["/src/utils/data/defs.d",
                  "/src/tests/test1.d",
                  "/src/utils/data/foo.d",
                  "/src/tests/test2.d",
                  "/src/utils/important.d",
                  "/src/utils/data/bar.d",
                  "/src/utils/also_important.d"
        ];
    auto byPackage = files.byPackage;
    byPackage.shouldInclude(["/src/tests/test1.d", "/src/tests/test1.d"]);
    byPackage.shouldInclude(["/src/utils/important.d", "/src/utils/also_important.d"]);
    byPackage.shouldInclude(["/src/utils/data/defs.d", "/src/utils/data/foo.d", "/src/utils/data/bar.d"]);
}
