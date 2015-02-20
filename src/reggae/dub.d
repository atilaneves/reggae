module reggae.dub;

import reggae.build;
import reggae.rules;
import std.algorithm: map;
import std.array: array;
import std.path: buildPath;


struct DubPackage {
    string name;
    string path;
    string mainSourceFile;
    string targetFileName;
    string[] flags;
    string[] importPaths;
    string[] stringImportPaths;
    string[] files;
}


struct DubInfo {
    DubPackage[] packages;

    Target[] toTargets() @safe pure const {
        Target[] targets;

        foreach(const pack; packages) {
            foreach(const file; pack.files) {
                targets ~= dCompile(buildPath(pack.path, file),
                                    pack.flags.join(" "),
                                    pack.importPaths,
                                    pack.stringImportPaths,
                                    pack.path);
            }
        }

        return targets;
    }

    //@trusted because of map.array
    string[] importPaths() @trusted const {
        string[] paths;
        foreach(const pack; packages) {
            paths ~= pack.importPaths.map!(a => buildPath(pack.path, a)).array;
        }
        return paths;
    }


    //@trusted because of map.array
    string[] stringImportPaths() @trusted const {
        string[] paths;
        foreach(const pack; packages) {
            paths ~= pack.stringImportPaths.map!(a => buildPath(pack.path, a)).array;
        }
        return paths;
    }
}
