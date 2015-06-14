module reggae.backend.tup;


import reggae.build;
import reggae.range;
import std.array;


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
                immutable line = ": " ~
                    target.dependencyFilesString(projectPath) ~ " |> " ~
                    target.shellCommand(projectPath) ~ " |> " ~
                    target.outputs.join(" ");
                    lines ~= line;
            }
        }
        return lines;
    }

private:
}
