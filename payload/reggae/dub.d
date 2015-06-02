module reggae.dub;

import reggae.build;
import reggae.rules;
import reggae.types;
import reggae.config: dflags, perModule;
import reggae.sorting;

public import std.typecons: Yes, No;
import std.typecons: Flag;
import std.algorithm: map, filter;
import std.array: array, join;
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

        foreach(const i, const dubPackage; packages) {
            const importPaths = dubPackage.allOf!(a => a.packagePaths(a.importPaths))(packages);
            const stringImportPaths = dubPackage.allOf!(a => a.packagePaths(a.stringImportPaths))(packages);
            const versions = dubPackage.allOf!(a => a.versions)(packages);
            //the path must be explicit for the other packages, implicit for the "main"
            //package
            const projDir = i == 0 ? "" : dubPackage.path;

            immutable flags = dubPackage.flags.join(" ") ~ dflags ~ " " ~
                versions.map!(a => "-version=" ~ a).join(" ");

            auto files = dubPackage.
                files.
                filter!(a => includeMain || a != dubPackage.mainSourceFile).
                map!(a => buildPath(dubPackage.path, a));

            targets ~= dCompileGrouped(files.array, flags, importPaths, stringImportPaths, projDir);
        }

        return targets;
    }

    //@trusted: array
    Target mainTarget(string flagsStr = "") @trusted const {
        string[] libs;
        foreach(p; packages) {
            libs ~= p.libs;
        }

        const pack = packages[0];
        auto flags = flagsStr.splitter(" ").array;
        flags ~= pack.targetType == "library" ? ["-lib"] : [];
        //hacky hack for dub describe on vibe.d projects
        flags ~= libs.filter!(a => a != "ev").map!(a => "-L-l" ~ a).array;
        return dLink(packages[0].targetFileName, toTargets(), flags.join(","));
    }

    string[] targetImportPaths() @trusted nothrow const {
        return packages[0].allOf!(a => a.packagePaths(a.importPaths))(packages);
    }

    string[][] fetchCommands() @safe pure nothrow const {
        return packages[0].dependencies.map!(a => ["dub", "fetch", a]).array;
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


Target dubMainTarget(string flags)() {
    import reggae.config;
    return dubInfo.mainTarget(flags);
}


Target dExeWithDubObjs(string exeName, alias objsFunction, Flags flags = Flags())
    () if(isSomeFunction!objsFunction) {
    import reggae.config;
    return dLink(exeName, objsFunction() ~ dubInfo.toTargets(No.main), flags.flags);
}

Target dExeWithDubObjsConfig(ExeName exeName,
                             Configuration config,
                             alias objsFunction = () { Target[] t; return t; },
                             Flags flags = Flags())()
    if(isSomeFunction!objsFunction) {

    import reggae.config;
    return dLink(exeName.name, objsFunction() ~ configToDubInfo[config.config].toTargets(Yes.main), flags.flags);
}
