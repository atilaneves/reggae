module tests.it.runtime.backend.binary;


import reggae;
import tests.it.runtime;


@("compile.once.runtime")
@Tags("binary")
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile(
            "reggaefile.d",
            q{
                import reggae;
                alias lib = staticLibrary!("mylib", Sources!"src");
                mixin build!lib;
            }
        );

        writeFile(
            "src/foo.d",
            q{
                module foo;
                import bar;

                void main() {

                }

                int foo(int i) {
                    return bar(i) * 2;
                }
            }
        );

        writeFile(
            "src/foo.d",
            q{
                module bar;
                int bar(int i) {
                    return i + 1;
                }
            }
        );

        runReggae(["-b", "binary"]);
        binary.shouldExecuteOk; // build the 1st time
        // shouldn't build the 2nd time
        const output = binary.shouldExecuteOk;
        writelnUt(output);
        "[build] Nothing to do".should.be in output;
    }
}

version(DigitalMars) {
    version(linux) {
        @("compile.once.reggaetime")
        @Tags("binary")
        unittest {
            import tests.utils: gCurrentFakeFile;

            with(immutable ReggaeSandbox()) {
                writeFile(
                    "reggaefile.d",
                    q{
                        import reggae;
                        alias lib = staticLibrary!("mylib", Sources!"src");
                        mixin build!lib;
                    }
                );

                writeFile(
                    "src/foo.d",
                    q{
                        module foo;
                        import bar;

                        void main() {

                        }

                        int foo(int i) {
                            return bar(i) * 2;
                        }
                    }
                );

                writeFile(
                    "src/foo.d",
                    q{
                        module bar;
                        int bar(int i) {
                            return i + 1;
                        }
                    }
                );

                runReggae(["-b", "ninja"]);
                writelnUt(gCurrentFakeFile.lines);
                gCurrentFakeFile.lines.shouldHaveCompiledBuildgen;
                gCurrentFakeFile.reset;

                runReggae(["-b", "ninja"]); // should not build reggaefile again
                writelnUt(gCurrentFakeFile.lines);
                gCurrentFakeFile.lines.shouldNotHaveCompiledBuildgen;
            }
        }
    }
}

void shouldHaveCompiledBuildgen(in string[] lines, in string file = __FILE__, in size_t line = __LINE__) {
    import std.algorithm: filter, canFind;
    lines
        .filter!(l => l.canFind("[build]"))
        .filter!(l => l.canFind("dmd "))
        .filter!(l => l.canFind("-of"))
        .shouldNotBeEmpty(file, line);
}


void shouldNotHaveCompiledBuildgen(in string[] lines, in string file = __FILE__, in size_t line = __LINE__) {
    import std.algorithm: filter, canFind;
    lines
        .filter!(l => l.canFind("[build]"))
        .filter!(l => l.canFind("dmd "))
        .filter!(l => l.canFind("-of"))
        .shouldBeEmpty(file, line);
}
