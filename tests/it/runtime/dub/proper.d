/**
   Tests for actual dub projects (i.e. that have a dub recipe)
*/
module tests.it.runtime.dub.proper;


import tests.it.runtime;
import reggae.reggae;
import reggae.path: buildPath;


@("noreggaefile.ninja")
@Tags(["dub", "ninja"])
unittest {

    import std.string: join;
    import std.algorithm: filter;

    with(immutable ReggaeSandbox("dub")) {
        shouldNotExist("reggaefile.d");
        writelnUt("\n\nReggae output:\n\n", runReggae("-b", "ninja").lines.join("\n"), "-----\n");
        shouldNotExist("reggaefile.d");
        auto output = ninja(["-v"]).shouldExecuteOk;

        version(Windows) {
            // args in response file
        } else {
            output.shouldContain("-debug -g");
        }

        shouldSucceed("atest").filter!(a => a != "").should ==
            [
                "Why hello!",
                "I'm immortal!"
            ];

        // there's only one UT in main.d which always fails
        ninja(["ut"]).shouldExecuteOk;
        shouldFail("atest-test-application");
    }
}

@("noreggaefile.tup")
@Tags(["dub", "tup"])
unittest {
    with(immutable ReggaeSandbox("dub")) {
        runReggae("-b", "tup").
            shouldThrowWithMessage("dub integration not supported with the tup backend");
    }
}


@("prebuild")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox("dub_prebuild")) {
        runReggae("-b", "ninja");
        ninja(["default", "ut"]).shouldExecuteOk;
        shouldSucceed("ut");
    }
}


version(Posix) {
    @("postbuild")
    @Tags(["dub", "ninja", "posix"])
    unittest {
        with(immutable ReggaeSandbox("dub_postbuild")) {
            runReggae("-b", "ninja");
            shouldNotExist("foo.txt");
            ninja.shouldExecuteOk;
            shouldExist("foo.txt");
            shouldSucceed("postbuild");
        }
    }
}


@("dependencies not on file system already no dub.selections.json")
@Flaky
@Tags("dub", "ninja", "online")
unittest {

    with(immutable ReggaeSandbox()) {
        writeFile("dub.json", `
        {
          "name": "depends_on_cerealed",
          "license": "MIT",
          "targetType": "executable",
          "dependencies": { "cerealed": "==0.6.8" }
        }`);
        writeFile("source/app.d", "void main() {}");

        runReggae("-b", "ninja");
    }
}


@("no main function but with unit tests")
@Tags("dub", "ninja", "online")
@Flaky
unittest {
    import std.file: mkdirRecurse;

    with(immutable ReggaeSandbox()) {
        writeFile("dub.json", `
            {
              "name": "depends_on_cerealed",
              "license": "MIT",
              "targetType": "executable",
              "dependencies": { "cerealed": "==0.6.8" }
            }`);

        writeFile("reggaefile.d", q{
            import reggae;
            mixin build!(dubTestTarget!());
        });

        mkdirRecurse(buildPath(testPath, "source"));
        writeFile("source/foo.d", `unittest { assert(false); }`);
        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;

        shouldFail("depends_on_cerealed-test-application");
    }
}


@("reggae/dub build should rebuild if dub.selections.json changes")
@Tags(["dub", "make"])
unittest {

    import std.process: execute;

    with(immutable ReggaeSandbox("dub_prebuild")) {
        runReggae("-b", "make");
        make(["VERBOSE=1"]).shouldExecuteOk.shouldContain("-debug -g");
        {
            const ret = execute(["touch", buildPath(testPath, "dub.selections.json")]);
            ret.status.shouldEqual(0);
        }
        {
            const ret = execute(["make", "-C", testPath]);
            ret.output.shouldContain("eggae");
        }
    }
}

@("version from main package is used in dependent packages")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            versions "lefoo"
            targetType "executable"
            dependency "bar" path="bar"
        `);
        writeFile("source/app.d", q{
            void main() {
                import bar;
                import std.stdio;
                writeln(lebar);
            }
        });
        writeFile("bar/dub.sdl", `
            name "bar"
        `);
        writeFile("bar/source/bar.d", q{
            module bar;
            version(lefoo)
                int lebar() { return 3; }
            else
                int lebar() { return 42; }
        });
        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldSucceed("foo").shouldEqual(
            [
                "3",
            ]
        );
    }
}


@("sourceLibrary dependency")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            targetType "executable"
            dependency "bar" path="bar"
        `);
        writeFile("source/app.d", q{
            void main() {
                import bar;
                import std.stdio;
                writeln(lebar);
            }
        });
        writeFile("bar/dub.sdl", `
            name "bar"
            targetType "sourceLibrary"
        `);
        writeFile("bar/source/bar.d", q{
            module bar;
            int lebar() { return 3; }
        });
        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
    }
}

version(DigitalMars) {
    @("object source files.simple")
    @Tags(["dub", "ninja"])
    unittest {
        with(immutable ReggaeSandbox()) {
            writeFile("dub.sdl", `
                name "foo"
                targetType "executable"
                dependency "bar" path="bar"
            `);
            writeFile("source/app.d", q{
                extern(C) int lebaz();
                void main() {
                    import bar;
                    import std.stdio;
                    writeln(lebar);
                    writeln(lebaz);
                }
            });
            writeFile("bar/dub.sdl", `
                name "bar"
                sourceFiles "../baz.o" platform="posix"
                sourceFiles "../baz.obj" platform="windows"
            `);
            writeFile("bar/source/bar.d", q{
                module bar;
                int lebar() { return 3; }
            });
            writeFile("baz.d", q{
                module baz;
                extern(C) int lebaz() { return 42; }
            });

            ["dmd", "-c", inSandboxPath("baz.d")].shouldExecuteOk;

            runReggae("-b", "ninja");
            ninja.shouldExecuteOk;
        }
    }
}

version(unittest)
private string getSingleSubdir(string parentDir) {
    import std.array, std.file;
    auto entries = dirEntries(parentDir, SpanMode.shallow).array;
    entries.length.should == 1;
    entries[0].isDir.should == true;
    return entries[0].name;
}

@("dub objs option path dependency")
@Tags("dub", "ninja", "dubObjsDir")
unittest {

    with(immutable ReggaeSandbox()) {

        writeFile("reggaefile.d", q{
            import reggae;
            mixin build!(dubBuild!());
        });

        writeFile("dub.sdl",`
            name "foo"
            targetType "executable"
            dependency "bar" path="bar"
        `);

        writeFile("source/app.d", q{
            import bar;
            void main() { add(2, 3); }
        });

        writeFile("bar/dub.sdl", `
            name "bar"
        `);

        writeFile("bar/source/bar.d", q{
            module bar;
            int add(int i, int j) { return i + j; }
        });

        const dubObjsDir = buildPath(testPath, "objsdir");
        const output = runReggae("-b", "ninja", "--dub-objs-dir=" ~ dubObjsDir, "--dub-deps-objs");
        writelnUt(output);
        ninja.shouldExecuteOk;

        const barObjsDir = buildPath(dubObjsDir, "bar");
        shouldExist(barObjsDir);
        const hashDir = getSingleSubdir(barObjsDir);
        const objPath = buildPath(hashDir, "source_bar" ~ objExt);
        shouldExist(objPath);
        shouldExist(objPath ~ ".dep");
    }
}


@("dub objs option registry dependency")
@Tags("dub", "ninja", "dubObjsDir")
unittest {

    with(immutable ReggaeSandbox()) {

        writeFile("reggaefile.d", q{
            import reggae;
            mixin build!(dubBuild!());
        });

        writeFile("dub.sdl",`
            name "foo"
            targetType "executable"
            dependency "dubnull" version="==0.0.1"
        `);

        writeFile("source/app.d", q{
            import dubnull;
            void main() { dummy(); }
        });

        const dubObjsDir = buildPath(testPath, "objsdir");
        const output = runReggae("-b", "ninja", "--dub-objs-dir=" ~ dubObjsDir, "--dub-deps-objs");
        writelnUt(output);

        ninja.shouldExecuteOk;

        const dubNullObjsDir = buildPath(dubObjsDir, "dubnull");
        shouldExist(dubNullObjsDir);
        const hashDir = getSingleSubdir(dubNullObjsDir);
        const objPath = buildPath(hashDir, "source_dubnull" ~ objExt);
        shouldExist(objPath);
        shouldExist(objPath ~ ".dep");
    }
}

version(DigitalMars) {
    @("object source files.with dub objs option")
    @Tags("dub", "ninja", "dubObjsDir")
    unittest {
        with(immutable ReggaeSandbox()) {
            writeFile("dub.sdl", `
                name "foo"
                targetType "executable"
                dependency "bar" path="bar"
            `);
            writeFile("source/app.d", q{
                extern(C) int lebaz();
                void main() {
                    import bar;
                    import std.stdio;
                    writeln(lebar);
                    writeln(lebaz);
                }
            });
            writeFile("bar/dub.sdl", `
                name "bar"
                sourceFiles "../baz.o" platform="posix"
                sourceFiles "../baz.obj" platform="windows"
            `);
            writeFile("bar/source/bar.d", q{
                module bar;
                int lebar() { return 3; }
            });
            writeFile("baz.d", q{
                module baz;
                extern(C) int lebaz() { return 42; }
            });

            ["dmd", "-c", inSandboxPath("baz.d")].shouldExecuteOk;

            const output = runReggae("-b", "ninja", "--dub-objs-dir=" ~ testPath);
            writelnUt(output);

            ninja.shouldExecuteOk;
        }
    }
}


@("dub with spaces")
@Tags("dub", "ninja")
unittest {
    /* Use Ninja to build a tiny dub project with spaces in:
     * - source directory
     * - source filename
     * - import directory
     * - compiler flags
     * - linker flags
     * - output filename
     */
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "dub_with_spaces"
            targetName "dub with spaces"
            targetType "executable"

            sourcePaths "my source"
            importPaths "my source"
            mainSourceFile "my source/my module.d"

            dflags "-L-Lmy libs" platform="posix"
            dflags "-L/LIBPATH:my libs" platform="windows"

            lflags "-Lmy other libs" platform="posix"
            lflags "/LIBPATH:my other libs" platform="windows"
        `);

        writeFile("my source/my module.d", q{
            module my_module;
            import other_module;
            void main() { foo(); }
        });

        writeFile("my source/other_module.d", q{
            void foo() {}
        });

        // use --per-module to test that Ninja accepts the .dep files
        // generated for both modules/objects
        const output = runReggae("-b", "ninja", "--per-module");
        writelnUt(output);

        ninja.shouldExecuteOk;

        shouldExist("dub with spaces" ~ exeExt);
    }
}


version(Posix) {
    @("depends on package with prebuild")
    @Tags(["dub", "ninja"])
    unittest {

        with(immutable ReggaeSandbox("dub_depends_on_prebuild")) {

            copyProject("dub_prebuild", buildPath("../dub_prebuild"));

            runReggae("-b", "ninja");
            ninja.shouldExecuteOk;
            shouldSucceed("app");
            shouldExist(inSandboxPath("../dub_prebuild/el_prebuildo.txt"));
        }
    }
}


@("staticLibrary.implicit")
@Tags(["dub", "ninja"])
unittest {

    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            targetType "executable"
            targetName "d++"

            configuration "executable" {
            }

            configuration "library" {
                targetType "library"
                targetName "dpp"
                excludedSourceFiles "source/main.d"
            }
        `);

        writeFile("reggaefile.d",
                  q{
                      import reggae;
                      alias lib = dubBuild!(Configuration("library"));
                      enum mainObj = objectFile!(SourceFile("source/main.d"));
                      alias exe = link!(ExeName("d++"), targetConcat!(lib, mainObj));
                      mixin build!(exe);
                  });

        writeFile("source/main.d", "void main() {}");
        writeFile("source/foo/bar/mod.d", "module foo.bar.mod; int add1(int i, int j) { return i + j + 1; }");

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldSucceed("d++");
    }
}


@("staticLibrary.explicit")
@Tags(["dub", "ninja"])
unittest {

    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            targetType "executable"
            targetName "d++"

            configuration "executable" {
            }

            configuration "library" {
                targetType "staticLibrary"
                targetName "dpp"
                excludedSourceFiles "source/main.d"
            }
        `);

        writeFile("reggaefile.d",
                  q{
                      import reggae;
                      alias lib = dubBuild!(Configuration("library"));
                      enum mainObj = objectFile!(SourceFile("source/main.d"));
                      alias exe = link!(ExeName("d++"), targetConcat!(lib, mainObj));
                      mixin build!(exe);
                  });

        writeFile("source/main.d", "void main() {}");
        writeFile("source/foo/bar/mod.d", "module foo.bar.mod; int add1(int i, int j) { return i + j + 1; }");

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldSucceed("d++");
    }
}


@("failing prebuild command")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox("dub_prebuild_oops")) {
        auto thrownInfo = runReggae("-b", "ninja").shouldThrow;
        "Error calling foo bar baz quux:".should.be in thrownInfo.msg;
        version(Windows) {
            enum expectedDetail = "'foo' is not recognized as an internal or external command";
        } else {
            enum expectedDetail = "not found";
        }
        expectedDetail.should.be in thrownInfo.msg;
    }
}


version(Posix) { // cannot be bothered debugging this on Windows
    @("libs.plain")
    @Tags(["dub", "ninja"])
    unittest {
        with(immutable ReggaeSandbox()) {
            writeFile("dub.sdl", `
                name "foo"
                targetType "executable"
                libs "utils"
                lflags "-L$PACKAGE_DIR" platform="posix"
                lflags "/LIBPATH:$PACKAGE_DIR" platform="windows"

                configuration "executable" {
                }

                configuration "library" {
                    targetType "library"
                    targetName "dpp"
                    excludedSourceFiles "source/main.d"
                }
            `);

            writeFile("reggaefile.d",
                      q{
                          import reggae;
                          alias exe = dubBuild!(
                          );
                          mixin build!(exe);
                      });

            writeFile("source/main.d",
                      q{
                          extern(C) int twice(int);
                          void main() {
                              assert(twice(2) == 4);
                              assert(twice(3) == 6);
                          }
                      });

            writeFile("utils.c", "int twice(int i) { return i * 2; }");
            version(Windows) {
                shouldExecuteOk(["cl.exe", "/Fo" ~ inSandboxPath("utils.obj"), "/c", inSandboxPath("utils.c")]);
                shouldExecuteOk(["lib.exe", "/OUT:" ~ inSandboxPath("utils.lib"), inSandboxPath("utils.obj")]);
            } else {
                shouldExecuteOk(["gcc", "-o", inSandboxPath("utils.o"), "-c", inSandboxPath("utils.c")]);
                shouldExecuteOk(["ar", "rcs", inSandboxPath("libutils.a"), inSandboxPath("utils.o")]);
            }

            runReggae("-b", "ninja");
            ninja.shouldExecuteOk;
            shouldSucceed("foo");
        }
    }
}


@("libs.posix")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            targetType "executable"
            libs "utils"
            lflags "-L$PACKAGE_DIR" platform="posix"
            lflags "/LIBPATH:$PACKAGE_DIR" platform="windows"

            configuration "executable" {
            }

            configuration "library" {
                targetType "library"
                targetName "dpp"
                excludedSourceFiles "source/main.d"
            }
        `);

        writeFile("reggaefile.d",
                  q{
                      import reggae;
                      alias exe = dubBuild!(
                      );
                      mixin build!(exe);
                  });

        writeFile("source/main.d",
                  q{
                      extern(C) int twice(int);
                      void main() {
                          assert(twice(2) == 4);
                          assert(twice(3) == 6);
                      }
                  });

        writeFile("utils.c", "int twice(int i) { return i * 2; }");
        version(Windows) {
            shouldExecuteOk(["cl.exe", "/Fo" ~ inSandboxPath("utils.obj"), "/c", inSandboxPath("utils.c")]);
            shouldExecuteOk(["lib.exe", "/OUT:" ~ inSandboxPath("utils.lib"), inSandboxPath("utils.obj")]);
        } else {
            shouldExecuteOk(["gcc", "-o", inSandboxPath("utils.o"), "-c", inSandboxPath("utils.c")]);
            shouldExecuteOk(["ar", "rcs", inSandboxPath("libutils.a"), inSandboxPath("utils.o")]);
        }

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldSucceed("foo");
    }
}


@("libs.dependency")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            targetType "executable"
            dependency "bar" path="bar"
        `);

        writeFile("reggaefile.d",
                  q{
                      import reggae;
                      mixin build!(dubBuild!());
                  });

        writeFile("source/main.d",
                  q{
                      import bar;
                      void main() {
                          assert(times4(2) == 8);
                          assert(times4(3) == 12);
                      }
                  });

        writeFile("bar/dub.sdl", `
            name "bar"
            targetType "library"
            lflags "-L$PACKAGE_DIR" platform="posix"
            lflags "/LIBPATH:$PACKAGE_DIR" platform="windows"
            libs "utils"
        `);

        writeFile("bar/source/bar.d", q{
                module bar;
                extern(C) int twice(int);
                int times4(int i) { return 2 * twice(i); }
            }
        );

        writeFile("bar/utils.c", "int twice(int i) { return i * 2; }");
        version(Windows) {
            shouldExecuteOk(["cl.exe", "/Fo" ~ inSandboxPath("bar/utils.obj"), "/c", inSandboxPath("bar/utils.c")]);
            shouldExecuteOk(["lib.exe", "/OUT:" ~ inSandboxPath("bar/utils.lib"), inSandboxPath("bar/utils.obj")]);
        } else {
            shouldExecuteOk(["gcc", "-o", inSandboxPath("bar/utils.o"), "-c", inSandboxPath("bar/utils.c")]);
            shouldExecuteOk(["ar", "rcs", inSandboxPath("bar/libutils.a"), inSandboxPath("bar/utils.o")]);
        }

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldSucceed("foo");
    }
}


@("dflags.debug")
@Tags("dub", "ninja")
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            targetType "executable"
        `);

        writeFile("source/main.d",
                  q{
                      void main() {
                          debug assert(false);
                      }
                  });

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldFail("foo");
    }
}


@("unittest.dependency")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            targetType "executable"
            dependency "bar" path="bar"
        `);
        writeFile("source/app.d", q{
            void main() {
            }
        });
        writeFile("bar/dub.sdl", `
            name "bar"
        `);
        writeFile("bar/source/bar.d", q{
            module bar;
            unittest {
                assert(1 == 2);
            }
        });
        runReggae("-b", "ninja");
        ninja(["default", "ut"]).shouldExecuteOk;
        shouldSucceed("foo-test-application");
    }
}


@("unittest.self")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            targetType "executable"
        `);
        writeFile("source/app.d", q{
            void main() {}
        });
        writeFile("source/test.d", q{
            unittest { assert(1 == 2); }
        });
        runReggae("-b", "ninja");
        ninja(["default", "ut"]).shouldExecuteOk;
        shouldFail("foo-test-application");
    }
}


@("subpackages")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.json", `
            {
                "name": "oops",
                "targetType": "none",
                "subPackages": [
                    {
                        "name": "pkg1",
                        "targetType": "staticLibrary"
                    },
                    {
                        "name": "pkg2",
                        "targetType": "executable",
                        "sourceFiles": ["main.d"],
                        "dependencies": {
                            "oops:pkg1": "*"
                        }
                    }
                ],
                "dependencies": {
                    "oops:pkg1": "*",
                    "oops:pkg2": "*"
                }
            }
        `);
        writeFile("main.d", q{
            void main() {
                import oops;
                import std.stdio;
                writeln(3.twice);
            }
        });
        writeFile("source/oops.d", q{
            module oops;
            int twice(int i) { return i * 2; }
        });

        runReggae("-b", "ninja");
        ninja(["default", "ut"]).shouldExecuteOk;
        shouldFail("ut");
    }
}


@("buildtype.release")
@Tags("dub", "ninja")
unittest {

    import std.string: splitLines;

    with(immutable ReggaeSandbox()) {
        writeFile(
            "dub.sdl",
            [
                `name "foo"`,
                `targetType "executable"`,
            ],
        );
        writeFile(
            "source/app.d",
            [
                q{void main() {}},
            ],
        );

        runReggae("-b", "ninja", "--dub-build-type=release");
        const buildLines = ninja(["-v"]).shouldExecuteOk;

        version(Windows) {
            // args in response file
        } else {
            const firstLine = buildLines[0];
            "-release ".should.be in firstLine;
            "-O".should.be in firstLine;
        }
    }

}


@("dynamicLibrary")
@Tags("dub", "ninja")
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile(
            "dub.sdl",
            [
                `name "foo"`,
                `targetType "dynamicLibrary"`,
            ],
        );
        writeFile(
            "source/mod.d",
            [
                q{
                    version (Windows) version (DigitalMars) {
                        import core.sys.windows.dll;
                        mixin SimpleDllMain;
                    }

                    void foo() {}
                },
            ],
        );

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
    }
}


@("extra dflags")
@Tags("dub", "ninja")
unittest {
    import std.file: readText;
    import std.string: replace;

    with(immutable ReggaeSandbox()) {
        writeFile(
            "dub.sdl",
            [
                `name "foo"`,
                `targetType "executable"`,
                `lflags "-some_flag"`,
            ],
        );
        writeFile(
            "source/app.d",
            [
                q{void main() {}},
            ],
        );

        runReggae("-b", "ninja", "--dub-build-type=plain", "--dflag=-Xcc=-fuse-ld=lld");
        readText(buildPath(currentTestPath, "build.ninja"))
            .replace(" -m64", "") // the model is added implicitly for DMD on Windows
            .shouldContain("-L-some_flag -Xcc=-fuse-ld=lld");
    }
}

version(LDC) {
    // tup isn't supported with dub anyway
    static foreach(backend; ["ninja", "make", /* FIXME "binary" */]) {
        static foreach(compiler; ["ldc2", /* FIXME "ldmd" */]) {
            @Tags("dub", backend)
            @("staticLibrary.noObjs." ~ compiler ~ "." ~ backend)
            unittest {
                import reggae.rules.common: objExt;
                import std.path: buildPath;

                with(immutable ReggaeSandbox()) {
                    writeFile(
                        "dub.sdl",
                        [
                            `name "foo"`,
                            `targetType "library"`,
                            `dependency "bar" path="bar"`
                        ]);
                    writeFile("source/foo.d", "");
                    writeFile(
                        "bar/dub.sdl",
                        [
                            `name "bar"`,
                            `targetType "library"`,
                        ]);
                    writeFile("bar/source/bar.d", "");
                    runReggae("-b", backend, "--dc=" ~ compiler);
                    // ldc should act like dmd and not generate object files when using
                    // -lib
                    mixin(backend).shouldExecuteOk;
                    shouldNotExist(buildPath("bar", "obj", "bar" ~ objExt));
                }
            }
        }
    }
}

@("custom.binary")
@Tags("binary")
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile(
            "dub.sdl",
            [
                `name "foo"`,
                `targetType "library"`,
            ]
        );
        writeFile("source/foo.d", "");
        writeFile(
            "reggaefile.d",
            [
                `import reggae;`,
                `mixin build!(dubBuild!());`,
            ]
        );
        runReggae("-b", "binary");
    }
}
