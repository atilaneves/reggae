module reggae.backend.tup;


import reggae.build;
import reggae.range;
import std.array;
import std.typecons;

@safe:

struct Tup {
    enum fileName = "Tupfile";

    Build build;
    string projectPath;

    string output() const pure {
        return lines.join("\n");
    }

    string[] lines() const pure {

        string[] lines;
        foreach(topTarget; build.targets) {
            foreach(target; DepthFirst(topTarget)) {
                if(target.command.getType == CommandType.code)
                    throw new Exception("Command type 'code' not supported for tup backend");

                //tup does its own dependency detection, trying to output
                //dependency files actually causes an error, so we request
                //none to be generated
                immutable line = ": " ~
                    target.dependencyFilesString(projectPath) ~ " |> " ~
                    target.shellCommand(projectPath, No.dependencies) ~ " |> " ~
                    target.outputs.join(" ");
                    lines ~= line;
            }
        }
        return lines;
    }

private:
}
