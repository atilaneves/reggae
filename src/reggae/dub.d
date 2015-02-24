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

    Target[] toTargets() @safe const {
        Target[] targets;

        foreach(const i, const pack; packages) {
            //the first package is special; it inherits imports
            //flags from all the others
            const importPaths = i == 0 ? allImportPaths : pack.importPaths;
            const stringImportPaths = i == 0 ? allStringImportPaths : pack.stringImportPaths;
            //the path must be explicit for the other packages, implicit for the "main"
            //package
            const projDir = i == 0 ? "" : pack.path;

            foreach(const file; pack.files) {
                targets ~= dCompile(buildPath(pack.path, file),
                                    pack.flags.join(" "),
                                    importPaths, stringImportPaths, projDir);
            }
        }

        return targets;
    }

    string[] allImportPaths() @safe const {
        return packages.allPaths!(a => a.importPaths);
    }


    string[] allStringImportPaths() @safe const {
        return packages.allPaths!(a => a.stringImportPaths);
    }
}

//@trusted because of map.array
private string[] allPaths(alias F)(in DubPackage[] packages) @trusted {
    string[] paths;
    foreach(const pack; packages) {
        paths ~= F(pack).map!(a => buildPath(pack.path, a)).array;
    }
    return paths;
}
