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
        return lines.join("\n") ~ "\n";
    }

    string[] lines() const pure {

        string[] lines;
        foreach(target; UniqueDepthFirst(build)) {
            if(target.getCommandType == CommandType.code)
                throw new Exception("Command type 'code' not supported for tup backend");

            //tup does its own dependency detection, trying to output
            //dependency files actually causes an error, so we request
            //none to be generated
            immutable line = ": " ~
                target.dependencyFilesString(projectPath) ~ " |> " ~
                target.shellCommand(projectPath, No.dependencies) ~ " |> " ~
                target.outputsInProjectPath(projectPath).join(" ");
            lines ~= line;
        }
        return lines;
    }
}
