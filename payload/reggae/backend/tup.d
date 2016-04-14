module reggae.backend.tup;


import reggae.build;
import reggae.range;
import reggae.options;
import std.array;
import std.typecons;

@safe:

struct Tup {
    enum fileName = "Tupfile";

    Build build;
    const(Options) options;

    this(Build build, in string projectPath) {
        import reggae.config: options;
        auto modOptions = options.dup;
        modOptions.projectPath = projectPath;
        this(build, modOptions);
    }

    this(Build build, in Options options) {
        this.build = build;
        this.options = options;
    }

    string output() pure {
        auto ret = banner ~ lines.join("\n") ~ "\n";
        if(options.export_) ret = options.eraseProjectPath(ret);
        return ret;
    }

    string[] lines() pure {

        string[] lines;
        foreach(target; build.range) {
            if(target.getCommandType == CommandType.code)
                throw new Exception("Command type 'code' not supported for tup backend");

            //tup does its own dependency detection, trying to output
            //dependency files actually causes an error, so we request
            //none to be generated
            immutable line = ": " ~
                target.dependenciesInProjectPath(options.projectPath).join(" ") ~ " |> " ~
                target.shellCommand(options, No.dependencies) ~ " |> " ~
                target.outputsInProjectPath(options.projectPath).join(" ");
            lines ~= line;
        }
        return lines;
    }

    void writeBuild() @system {
        import std.file;
        import std.string;
        import std.stdio;

        if(!".tup".exists) {
            import std.process;
            immutable args = ["tup", "init"];
            try
                execute(args);
            catch(ProcessException _)
                stderr.writeln("Could not execute '", args.join(" "), "'. tup builds need to do that first.");
        }
        auto file = File(fileName, "w");
        file.write(output);
    }
}
