module tests.it.runtime.dependencies;


import tests.it.runtime;


version(DigitalMars) {
    // don't bother with binary since it's run with --norerun
    static foreach(backend; ["ninja", "make"]) {
        @("reggaefile.imports." ~ backend)
        @Tags(backend)
        unittest {
            with(immutable ReggaeSandbox()) {
                writeFile(
                    "reggaefile.d",
                    q{
                        import reggae;
                        import other.constants;
                        alias exe = executable!(ExeName(exeName), Sources!("source"));
                        mixin build!exe;
                    }
                );
                writeFile(
                    "other/constants.d",
                    q{
                        module other.constants;
                        enum exeName = "foo"; void lefoo() { }
                    }
                );
                writeFile("source/main.d", "void main() { }");

                runReggae("-b", backend, "--verbose");
                mixin(backend).shouldExecuteOk;

                // Rerunning reggae fails in this fake environment because there is no
                // reggae binary to rerun. So this is a hack because it tracks whether or
                // not we rerun reggae by having the call to reggae fail at runtime.
                // We trigger this by writing to constants.d which should have correctly
                // been identified as an implicit dependency of the reggaefile.
                // If things actually worked, we'd assert that there's now a file named
                // `bar`.
                writeFile(
                    "other/constants.d",
                    q{
                        module other.constants;
                        enum exeName = "bar"; void lefoo() { }
                    }
                );
                mixin(backend).shouldFailToExecute.shouldContain("reggae");

                runReggae("-b", backend); // but this should be fine
                mixin(backend).shouldExecuteOk; // it's rerun, so ninja succeeds

                // test that adding a file triggers a rerun
                writeFile("source/foo.d");
                mixin(backend).shouldFailToExecute.shouldContain("reggae");
            }
        }
 }
}

version(DigitalMars) {
    version(linux) {

        static foreach(backend; ["ninja", "make"]) {

            @("change.compiler." ~ backend)
            @Tags(backend)
            unittest {
                with(immutable ReggaeSandbox()) {

                    auto execute(string[] args) {
                        import std.process: execute_ = execute, Config;
                        string[string] env;
                        return execute_(args, env, Config.none, size_t.max, testPath);
                    }

                    void buildFakeCompiler(int returnCode= 0) {
                        enum fakeCompilerSrc = "compiler.d";
                        writeFile(fakeCompilerSrc, fakeCompilerCode(returnCode));

                        execute(["dmd", inSandboxPath(fakeCompilerSrc)])
                            .status
                            .should == 0;
                    }

                    buildFakeCompiler;
                    const fakeCompiler = inSandboxPath("compiler");
                    execute([fakeCompiler, "-h"]).status.should == 0;

                    writeFile("reggaefile.d", q{
                        import reggae;
                        alias mylib = staticLibrary!("mylib", Sources!"src");
                        mixin build!mylib;
                    });

                    writeFile("src/foo.d", q{
                        void foo() {}
                    });

                    runReggae("-b", backend, "--dc=" ~ fakeCompiler);
                    mixin(backend).shouldExecuteOk;
                    mixin(backend).shouldExecuteOk; // no-op build

                    // change the compiler, the code should rebuild
                    buildFakeCompiler(42);
                    // should fail because the compiler always fails now
                    mixin(backend).shouldFailToExecute(testPath);
                }
            }
        }


        private string fakeCompilerCode(int customStatus = 0) @safe pure {
            import std.format: format;
            import std.conv: text;

            return q{
                int main(string[] args) {
                    import std.process;
                    import std.stdio;

                    auto ret =  execute("dmd" ~ args[1..$]);
                    return %s;
                }
            }.format(customStatus == 0 ? `ret.status` : customStatus.text);
        }
    }
}

@("reggaefile.imports.explicitpath")
@Tags("ninja")
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile(
            "reggaefile.d",
            q{
                import reggae;
                import foo.bar;
                mixin build!(executable!(ExeName("foo"), Sources!("source")));
            }
        );
        writeFile(
            "source/app.d",
            q{void main() {}}
        );
        writeFile("other/foo/bar.d", "module foo.bar;");
        runReggae("-b", "ninja", "--reggaefile-import-path=" ~ inSandboxPath("other"));
    }
}
