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
                shouldSucceed("foo");

                // Writing to constants.d, which should have correctly been
                // identified as an implicit dependency of the reggaefile,
                // reruns reggae and the build now produces `bar` instead
                // of `foo`.
                writeFile(
                    "other/constants.d",
                    q{
                        module other.constants;
                        enum exeName = "bar"; void lefoo() { }
                    }
                );
                mixin(backend).shouldExecuteOk;
                shouldSucceed("bar");

                // test that adding a file triggers a rerun
                writeFile("source/foo.d");
                mixin(backend)
                    .shouldExecuteOk
                    .shouldNotContain("Build description unchanged");
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

                    runReggae("-b", backend, "--dc=" ~ fakeCompiler, "--build-reggaefile-with-dub");
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


@("payload")
@Tags("ninja", "dub")
@Flaky
unittest {
    import std.algorithm: map, countUntil;

    with(immutable ReggaeSandbox()) {
        writeFile(
            "reggaefile.d",
            q{
                import reggae;
                mixin build!(dubBuild!());
            }
        );
        writeFile(
            "dub.sdl",
            [
                `name "foo"`,
                `targetType "executable"`,
            ]
        );
        writeFile(
            "source/app.d",
            q{void main() {}}
        );

        static chomp(in string s) {
            // count until the time in seconds and jump the spaces
            return s[s.countUntil('s') + 3 .. $];
        }

        auto runIt(A...)(auto ref A args) {
            return runReggae(args).lines.map!chomp;
        }

        enum srcLine = "Writing reggae source files";
        enum cfgLine = "Writing reggae configuration";

        {
            auto lines = runIt;
            srcLine.should.be in lines;
            cfgLine.should.be in lines;
        }

        {
            // do not write files if nothing has changed
            auto lines = runIt;
            srcLine.should.not.be in lines;
            cfgLine.should.not.be in lines;
        }

        {
            // but do write configuration if reggae cfg has changed
            auto lines = runIt("-d myvar=foo");
            srcLine.should.not.be in lines;
            cfgLine.should.be in lines;
        }

        {
            // do not write files if nothing has changed
            // still using `myvar` cos otherwise that change would trigger writing
            auto lines = runIt("-d myvar=foo");
            srcLine.should.not.be in lines;
            cfgLine.should.not.be in lines;
        }

        {
            writeFile(
                "dub.sdl",
                [
                    `name "bar"`,
                    `targetType "executable"`,
                ]
            );

            // we cache dub's PackageManager per-thread; use a new thread to make sure the changed .sdl is reloaded
            import core.thread: Thread;
            new Thread(() {
                // but do write configuration if dub cfg has changed
                auto lines = runIt("-d myvar=foo");
                srcLine.should.not.be in lines;
                cfgLine.should.be in lines;
            }).start().join();
        }
    }
}


// Regression test for a bug where a Ninja rule for a target with its own
// per-target compiler options (`Target.withOptions`, as applied to every
// dub target by `rules.dub.runtime.dubBuild`) got a numbered rule
// (`_dcompile_N`) that was missing the `deps`/`depfile` lines the generic
// rule has. Ninja never read the `-makedeps` output for such targets, so
// editing an imported module didn't rebuild objects that imported it.
@("reggaefile.imports.rebuild.numbered-rule.ninja")
@Tags("ninja")
unittest {
    import reggae.rules.common: objExt;
    import std.file: timeLastModified;
    import core.thread: Thread;
    import core.time: msecs;

    with(immutable ReggaeSandbox()) {
        writeFile("b.d", q{
            module b;
            enum bValue = 1;
        });
        writeFile("a.d", q{
            module a;
            import b;
            enum aValue = bValue;
        });
        writeFile("unrelated.d", q{
            module unrelated;
            enum unrelatedValue = 1;
        });

        // Give `a.o` and `unrelated.o` their own per-target compiler
        // options (identical to the global ones is enough) so Ninja
        // generates numbered `_dcompile_N` rules for them, the same way
        // it does for every object file of every dub target.
        writeFile("reggaefile.d", q{
            import reggae;
            import reggae.config: options;

            auto obj(string source) {
                auto targetOptions = options.dup;
                return objectFile(targetOptions, SourceFile(source))
                    .withOptions(targetOptions);
            }

            Build reggaeBuild() {
                return Build(obj("a.d"), obj("unrelated.d"));
            }

            mixin BuildgenMain;
        });

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;

        const aObj = inSandboxPath("a" ~ objExt);
        const unrelatedObj = inSandboxPath("unrelated" ~ objExt);
        shouldExist(aObj);
        shouldExist(unrelatedObj);

        // Some filesystems only have 1-second mtime resolution; sleep so
        // that a rebuild is guaranteed to bump the recorded mtime.
        Thread.sleep(1100.msecs);

        const aBefore = timeLastModified(aObj);
        const unrelatedBefore = timeLastModified(unrelatedObj);

        // `b.d` is not a `Sources()` input of `a.o`'s target: it's only
        // known to Ninja via the depfile dmd writes with `-makedeps`.
        // Ninja must still rebuild `a.o` when `b.d` changes, but must
        // leave the unrelated object alone.
        writeFile("b.d", q{
            module b;
            enum bValue = 2;
        });

        ninja.shouldExecuteOk;

        (timeLastModified(aObj) > aBefore).should == true;
        timeLastModified(unrelatedObj).should == unrelatedBefore;
    }
}
