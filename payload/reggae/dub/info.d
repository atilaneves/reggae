module reggae.dub.info;

import reggae.build;
import reggae.rules;
import reggae.types;
import reggae.sorting;

public import std.typecons: Yes, No;
import std.typecons: Flag;
import std.algorithm: map, filter, find, splitter;
import std.array: array, join;
import std.path: buildPath;
import std.traits: isCallable;
import std.range: chain;

struct DubPackage {
    string name;
    string path;
    string mainSourceFile;
    string targetFileName;
    string[] dflags;
    string[] lflags;
    string[] importPaths;
    string[] stringImportPaths;
    string[] files;
    string targetType;
    string[] versions;
    string[] dependencies;
    string[] libs;
    bool active;
    string[] preBuildCommands;
}

bool isStaticLibrary(in string fileName) @safe pure nothrow {
    import std.path: extension;
    return fileName.extension == ".a";
}

bool isObjectFile(in string fileName) @safe pure nothrow {
    import reggae.rules.common: objExt;
    import std.path: extension;
    return fileName.extension == objExt;
}

string inDubPackagePath(in string packagePath, in string filePath) @safe pure nothrow {
    import std.path: buildPath;
    import std.algorithm: startsWith;
    return filePath.startsWith("$project")
        ? filePath
        : buildPath(packagePath, filePath);
}

struct DubInfo {

    DubPackage[] packages;

    Target[] toTargets(Flag!"main" includeMain = Yes.main,
                       in string compilerFlags = "",
                       Flag!"allTogether" allTogether = No.allTogether) @safe const {

        import reggae.config: options;
        import std.functional: not;

        Target[] targets;

        // -unittest should only apply to the main package
        string deUnitTest(T)(in T index, in string flags) {
            import std.string: replace;
            return index == 0
                ? flags
                : flags.replace("-unittest", "").replace("-main", "");
        }

        const(string)[] getVersions(T)(in T index) {
            import std.algorithm: map;
            import std.array: array;

            const(string)[] ret = index == 0
                ? packages[index].allOf!(a => a.versions)(packages)
                : packages[0].versions ~ packages[index].versions;

            return ret.map!(a => "-version=" ~ a).array;
        }

        foreach(const i, const dubPackage; packages) {
            const importPaths = allImportPaths();
            const stringImportPaths = dubPackage.allOf!(a => a.packagePaths(a.stringImportPaths))(packages);
            auto versions = getVersions(i);

            //the path must be explicit for the other packages, implicit for the "main"
            //package
            const projDir = i == 0 ? "" : dubPackage.path;

            immutable flags = chain(dubPackage.dflags,
                                    versions,
                                    [options.dflags],
                                    [deUnitTest(i, compilerFlags)])
                .join(" ");

            const files = dubPackage.files.
                filter!(a => includeMain || a != dubPackage.mainSourceFile).
                filter!(not!isStaticLibrary).
                filter!(not!isObjectFile).
                map!(a => buildPath(dubPackage.path, a))
                .array;

            auto func = allTogether ? &dlangPackageObjectFilesTogether : &dlangPackageObjectFiles;
            targets ~= func(files, flags, importPaths, stringImportPaths, projDir);
            // add any object files that are meant to be linked
            targets ~= dubPackage
                .files
                .filter!isObjectFile
                .map!(a => Target(inDubPackagePath(dubPackage.path, a)))
                .array;
        }

        return targets ~ allStaticLibrarySources;
    }

    TargetName targetName() @safe const pure nothrow {
        return TargetName(packages[0].targetFileName);
    }

    string targetType() @safe const pure nothrow {
        return packages[0].targetType;
    }

    string[] mainLinkerFlags() @safe pure nothrow const {
        import std.array: join;

        const pack = packages[0];
        return (pack.targetType == "library" || pack.targetType == "staticLibrary") ? ["-lib"] : [];
    }

    string[] linkerFlags() @safe const pure nothrow {
        const allLibs = packages.map!(a => a.libs).join;
        return
            allLibs.map!(a => "-L-l" ~ a).array ~
            packages.map!(a => a.lflags.map!(b => "-L" ~ b)).join;
    }

    string[] allImportPaths() @safe nothrow const {
        import reggae.config: options;

        string[] paths;
        auto rng = packages.map!(a => a.packagePaths(a.importPaths));
        foreach(p; rng) paths ~= p;
        return paths ~ options.projectPath;
    }

    // must be at the very end
    private Target[] allStaticLibrarySources() @trusted nothrow const pure {
        import std.algorithm: filter, map;
        import std.array: array, join;
        return packages.
            map!(a => cast(string[])a.files.filter!isStaticLibrary.array).
            join.
            map!(a => Target(a)).
            array;
    }
}


private auto packagePaths(in DubPackage dubPackage, in string[] paths) @trusted nothrow {
    return paths.map!(a => buildPath(dubPackage.path, a)).array;
}

//@trusted because of map.array
private string[] allOf(alias F)(in DubPackage pack, in DubPackage[] packages) @trusted nothrow {

    import std.algorithm: find;
    import std.array: array, empty, front;

    string[] result;
    //foreach(d; [pack.name] ~ pack.dependencies) doesn't compile with CTFE
    //it seems to have to do with constness, replace string[] with const(string)[]
    //and it won't compile
    const dependencies = [pack.name] ~ pack.dependencies;
    foreach(dependency; dependencies) {

        auto depPack = packages.find!(a => a.name == dependency);
        if(!depPack.empty) {
            result ~= F(depPack.front).array;
        }
    }
    return result;
}
