module reggae.dub;

import reggae.build;
import reggae.rules;
import reggae.config: dflags;
public import std.typecons: Yes, No;
import std.typecons: Flag;
import std.algorithm: map, filter;
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
    string[] libs;
}


struct DubInfo {
    DubPackage[] packages;

    Target[] toTargets(Flag!"main" includeMain = Yes.main) @safe const {
        Target[] targets;

        foreach(const i, const pack; packages) {
            const importPaths = pack.allOf!(a => a.packagePaths(a.importPaths))(packages);
            const stringImportPaths = pack.allOf!(a => a.packagePaths(a.stringImportPaths))(packages);
            const versions = pack.allOf!(a => a.versions)(packages);
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

    //@trusted: array
    Target mainTarget(string flagsStr = "") @trusted const {
        const pack = packages[0];
        string[] libs;
        foreach(p; packages) {
            libs ~= p.libs;
        }

        auto flags = flagsStr.splitter(" ").array;
        flags ~= pack.targetType == "library" ? ["-lib"] : [];
        //hacky hack for dub describe on vibe.d projects
        flags ~= libs.filter!(a => a != "ev").map!(a => "-L-l" ~ a).array;
        return dLink(packages[0].targetFileName, toTargets(), flags.join(","));
    }

    string[] targetImportPaths() @trusted nothrow const {
        return packages[0].allOf!(a => a.packagePaths(a.importPaths))(packages);
    }
}


private auto packagePaths(in DubPackage pack, in string[] paths) @trusted nothrow {
    return paths.map!(a => buildPath(pack.path, a)).array;
}

//@trusted because of map.array
private string[] allOf(alias F)(in DubPackage pack, in DubPackage[] packages) @trusted nothrow {
    string[] paths;
    //foreach(d; [pack.name] ~ pack.dependencies) doesn't compile with CTFE
    //it seems to have to do with constness, replace string[] with const(string)[]
    //and it won't compile
    string[] dependencies = [pack.name];
    dependencies ~= pack.dependencies;
    foreach(dependency; dependencies) {
        import std.range;
        const depPack = packages.find!(a => a.name == dependency).front;
        paths ~= F(depPack).array;
    }
    return paths;
}
