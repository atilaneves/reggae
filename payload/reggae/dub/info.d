module reggae.dub.info;

import reggae.build;
import reggae.rules;
import reggae.types;
import reggae.sorting;
import reggae.options: Options;

public import std.typecons: Yes, No;
import std.typecons: Flag;
import std.algorithm: map, filter, find, splitter;
import std.array: array, join;
import std.path: buildPath;
import std.traits: isCallable;
import std.range: chain;

enum TargetType {
    autodetect,
    none,
    executable,
    library,
    sourceLibrary,
    dynamicLibrary,
    staticLibrary,
    object,
}


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
    TargetType targetType;
    string[] versions;
    string[] dependencies;
    string[] libs;
    bool active;
    string[] preBuildCommands;
    string[] postBuildCommands;

    string toString() @safe pure const {
        import std.string: join;
        import std.conv: to;
        import std.traits: Unqual;

        auto ret = `DubPackage(`;
        string[] lines;

        foreach(ref elt; this.tupleof) {
            static if(is(Unqual!(typeof(elt)) == TargetType))
                lines ~= `TargetType.` ~ elt.to!string;
            else static if(is(Unqual!(typeof(elt)) == string))
                lines ~= "`" ~ elt.to!string ~ "`";
            else
                lines ~= elt.to!string;
        }
        ret ~= lines.join(`, `);
        ret ~= `)`;
        return ret;
    }

    DubPackage dup() @safe pure nothrow const {
        DubPackage ret;
        foreach(i, member; this.tupleof) {
            static if(__traits(compiles, member.dup))
                ret.tupleof[i] = member.dup;
            else
                ret.tupleof[i] = member;
        }
        return ret;
    }
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

struct DubObjsDir {
    string globalDir;
    string targetDir;
}

struct DubInfo {

    DubPackage[] packages;

    DubInfo dup() @safe pure nothrow const {
        import std.algorithm: map;
        import std.array: array;
        return DubInfo(packages.map!(a => a.dup).array);
    }

    Target[] toTargets(in Flag!"main" includeMain = Yes.main,
                       in string compilerFlags = "",
                       in Flag!"allTogether" allTogether = No.allTogether,
                       in DubObjsDir dubObjsDir = DubObjsDir())
        @safe const
    {

        import reggae.config: options;
        import reggae.build: targetObjsDir;
        import reggae.path: deabsolutePath;
        import std.functional: not;
        import std.string: replace;
        import std.path: buildPath, absolutePath, baseName, dirName;
        import std.range: only;

        Target[] targets;

        // -unittest should only apply to the main package
        string deUnitTest(T)(in T index, in string flags) {
            import std.string: replace;
            return index == 0
                ? flags
                : flags.replace("-unittest", "").replace("-main", "");
        }

        foreach(const i, const dubPackage; packages) {
            const importPaths = allImportPaths();
            const stringImportPaths = dubPackage.allOf!(a => a.packagePaths(a.stringImportPaths))(packages);
            const isMainPackage = i == 0;
            //the path must be explicit for the other packages, implicit for the "main"
            //package
            const projDir = isMainPackage ? "" : dubPackage.path;

            const sharedFlag = targetType == TargetType.dynamicLibrary ? ["-fPIC"] : [];

            immutable flags = chain(dubPackage.dflags,
                                    dubPackage.versions.map!(a => "-version=" ~ a),
                                    only(options.dflags),
                                    sharedFlag,
                                    only(archFlag(options)),
                                    only(deUnitTest(i, compilerFlags)))
                .join(" ");

            const files = dubPackage.files.
                filter!(a => includeMain || a != dubPackage.mainSourceFile).
                filter!(not!isStaticLibrary).
                filter!(not!isObjectFile).
                map!(a => buildPath(dubPackage.path, a))
                .array;

            auto func = allTogether ? &dlangPackageObjectFilesTogether : &dlangPackageObjectFiles;
            auto packageTargets = func(files, flags, importPaths, stringImportPaths, projDir);

            // e.g. /foo/bar -> foo/bar
            const deabsWorkingDir = options.workingDir.deabsolutePath;

            // go through dub dependencies and optionally put the object files in dubObjsDir
            if(!isMainPackage && dubObjsDir.globalDir != "") {
                foreach(ref target; packageTargets) {
                    target.rawOutputs[0] = buildPath(dubObjsDir.globalDir,
                                                     options.projectPath.deabsolutePath,
                                                     dubObjsDir.targetDir,
                                                     target.rawOutputs[0]);
                }
            }

            // add any object files that are meant to be linked
            packageTargets ~= dubPackage
                .files
                .filter!isObjectFile
                .map!(a => Target(inDubPackagePath(dubPackage.path, a)))
                .array;


            targets ~= packageTargets;
        }

        return targets ~ allStaticLibrarySources;
    }

    TargetName targetName() @safe const pure nothrow {
        const fileName = packages[0].targetFileName;
        return .targetName(targetType, fileName);
    }

    TargetType targetType() @safe const pure nothrow {
        return packages[0].targetType;
    }

    string[] mainLinkerFlags() @safe pure nothrow const {
        import std.array: join;

        const pack = packages[0];
        return (pack.targetType == TargetType.library || pack.targetType == TargetType.staticLibrary)
            ? ["-shared"]
            : [];
    }

    // template due to purity - in the 2nd build with the payload this is pure,
    // but in the 1st build to generate the reggae executable it's not.
    // See reggae.config.
    string[] linkerFlags()() const {
        import reggae.config: options;
        import std.array: join;

        const allLibs = packages.map!(a => a.libs).join;

        string libFlag(in string lib) {
            version(Posix)
                return "-L-l" ~ lib;
            else {
                import reggae.config: options;
                import reggae.options: DubArchitecture;

                final switch(options.dubArch) with(DubArchitecture) {
                    case x86:
                        return "-L-l" ~ lib;
                    case x86_64:
                    case x86_mscoff:
                        return lib ~ ".lib";
                }
            }
        }

        return
            allLibs.map!libFlag.array ~
            archFlag(options) ~
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

    // all postBuildCommands in one shell command. Empty if there are none
    string postBuildCommands() @safe pure nothrow const {
        import std.string: join;
        return packages[0].postBuildCommands.join(" && ");
    }
}


private auto packagePaths(in DubPackage dubPackage, in string[] paths) @trusted nothrow {
    return paths.map!(a => buildPath(dubPackage.path, a)).array;
}

//@trusted because of map.array
private string[] allOf(alias F)(in DubPackage pack, in DubPackage[] packages) @trusted nothrow {

    import std.range: chain, only;
    import std.array: array, front, empty;

    string[] result;

    foreach(dependency; chain(only(pack.name), pack.dependencies)) {
        auto depPack = packages.find!(a => a.name == dependency);
        if(!depPack.empty) {
            result ~= F(depPack.front).array;
        }
    }
    return result;
}

// The arch flag doesn't show up in dub describe. Sigh.
private string archFlag(in Options options) @safe pure nothrow {
    import reggae.options: DubArchitecture;

    final switch(options.dubArch) with(DubArchitecture) {
        case DubArchitecture.x86:
            return "-m32";
        case DubArchitecture.x86_64:
            return "-m64";
        case DubArchitecture.x86_mscoff:
            return "-m32mscoff";
    }
}

TargetName targetName(in TargetType targetType, in string fileName) @safe pure nothrow {

    import reggae.rules.common: exeExt;

    switch(targetType) with(TargetType) {
    default:
        return TargetName(fileName);

    case executable:
        version(Posix)
            return TargetName(fileName);
        else
            return TargetName(fileName ~ exeExt);

    case library:
        version(Posix)
            return TargetName("lib" ~ fileName ~ ".a");
        else
            return TargetName(fileName ~ ".lib");

    case dynamicLibrary:
        version(Posix)
            return TargetName("lib" ~ fileName ~ ".so");
        else
            return TargetName(fileName ~ ".dll");
    }
}
