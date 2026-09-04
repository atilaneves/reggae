module tests.it.buildgen.mixed_options;


version(Posix):

import tests.it.runtime;


@("ninja uses each target's compiler")
@Tags("ninja")
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("compiler-first", q{
            #!/bin/sh
            for arg do
                case "$arg" in
                    -of*) output=${arg#-of} ;;
                esac
            done
            : > "$output"
            : > first-used
        });
        writeFile("compiler-second", q{
            #!/bin/sh
            for arg do
                case "$arg" in
                    -of*) output=${arg#-of} ;;
                esac
            done
            : > "$output"
            : > second-used
        });
        writeFile("first.d", "module first;");
        writeFile("second.d", "module second;");
        ["chmod", "+x", "compiler-first", "compiler-second"].shouldExecuteOk;
        writeFile("reggaefile.d", q{
            import reggae;
            import reggae.config: options;

            auto target(string source, string script) {
                auto targetOptions = options.dup;
                targetOptions.dCompiler = "./" ~ script;
                return objectFile(targetOptions, SourceFile(source))
                    .withOptions(targetOptions);
            }

            Build reggaeBuild() {
                return Build(target("first.d", "compiler-first"),
                             target("second.d", "compiler-second"));
            }

            mixin BuildgenMain;
        });

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldExist("first-used");
        shouldExist("second-used");
    }
}
