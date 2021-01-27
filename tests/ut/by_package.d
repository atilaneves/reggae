module tests.ut.by_package;


import unit_threaded;
import reggae.sorting;



@("byPackage") unittest {
    auto files = ["/src/utils/data/defs.d",
                  "/src/tests/test1.d",
                  "/src/utils/data/foo.d",
                  "/src/tests/test2.d",
                  "/src/utils/important.d",
                  "/src/utils/data/bar.d",
                  "/src/utils/also_important.d"
        ];
    files.byPackage.shouldBeSameSetAs([
        ["/src/tests/test1.d", "/src/tests/test2.d"],
        ["/src/utils/important.d", "/src/utils/also_important.d"],
        ["/src/utils/data/defs.d", "/src/utils/data/foo.d", "/src/utils/data/bar.d"]
        ]);
}


@("packagePath") unittest {
    import reggae.path : buildPath;
    "src/utils/data/defs.d".packagePath.shouldEqual(buildPath("src/utils/data"));
}
