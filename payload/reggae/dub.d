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
    string[] dependencies;
}


struct DubInfo {
    DubPackage[] packages;

    Target[] toTargets(Flag!"main" includeMain = Yes.main) @safe const {
        Target[] targets;

        foreach(const i, const pack; packages) {
            const importPaths = pack.allPaths!(a => a.packagePaths(a.importPaths))(packages);
            const stringImportPaths = pack.allPaths!(a => a.packagePaths(a.stringImportPaths))(packages);
            const versions = pack.allPaths!(a => a.versions)(packages);
            //the path must be explicit for the other packages, implicit for the "main"
            //package
            const projDir = i == 0 ? "" : pack.path;

            foreach(const file; pack.files) {
                if(file == pack.mainSourceFile && !includeMain) continue;
                immutable flags = pack.flags.join(" ") ~ dflags ~ " " ~
                    versions.map!(a => "-version=" ~ a).join(" ");

                targets ~= dCompile(buildPath(pack.path, file),
                                    flags,
                                    importPaths, stringImportPaths, projDir);
            }
        }

        return targets;
    }

    Target target() @safe const {
        immutable flags = packages[0].targetType == "library" ? "-lib" : "";
        return dLink(packages[0].targetFileName, toTargets(), flags);
    }
}

private auto packagePaths(in DubPackage pack, in string[] paths) @safe pure nothrow {
    return paths.map!(a => buildPath(pack.path, a));
}

//@trusted because of map.array
private string[] allPaths(alias F)(in DubPackage pack, in DubPackage[] packages) @trusted nothrow {
    string[] paths;
    foreach(dependency; [pack.name] ~ pack.dependencies) {
        import std.range;
        const depPack = packages.find!(a => a.name == dependency).front;
        paths ~= F(depPack).array;
    }
    return paths;
}
