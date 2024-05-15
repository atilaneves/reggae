module tests.it.runtime.backend.binary;


import reggae;
import tests.it.runtime;


@("compile.once")
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
        "[build] Nothing to do".should.be in output;
        writelnUt(output);
    }
}
