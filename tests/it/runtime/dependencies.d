module tests.it.runtime.dependencies;


import tests.it.runtime;

version(DigitalMars):
version(linux):

static foreach(backend; ["ninja", "make", "binary"]) {

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
