module reggae.dub;

import reggae.build;
import reggae.rules;
import reggae.config: dflags;
public import std.typecons: Yes, No;
import std.typecons: Flag;
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
    string targetType;
    string[] versions;
}


struct DubInfo {
    DubPackage[] packages;

    Target[] toTargets(Flag!"main" includeMain = Yes.main) @safe const {
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
                if(file == pack.mainSourceFile && !includeMain) continue;
                immutable flags = pack.flags.join(" ") ~ dflags ~
                    pack.versions.map!(a => "-version=" ~ a).join(" ");

                targets ~= dCompile(buildPath(pack.path, file),
                                    flags,
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

    Target target() @safe const {
        immutable flags = packages[0].targetType == "library" ? "-lib" : "";
        return dLink(packages[0].targetFileName, toTargets(), flags);
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
