module tests.it.rules.static_lib;

import tests.it.runtime;

@("C archiver command in ninja rule")
@Tags("ninja")
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile(
            "reggaefile.d",
            q{
                import reggae;
                alias lib = staticLibrary!("mylib", Sources!("src"));
                mixin build!lib;
            }
        );

        writeFile("src/foo.c", "void foo() {}");
        runReggae("-b", "ninja");

        version(Windows) // should have resolved path to lib.exe
            fileShouldContain("build.ninja", `\lib.exe" /OUT:`);
        else
            fileShouldContain("build.ninja", "before = ar rcs ");
    }
}
