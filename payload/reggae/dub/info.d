module reggae.dub.info;

import reggae.build;
import reggae.types;
import reggae.sorting;
import reggae.options: Options;
import reggae.path: buildPath;
import std.algorithm: map, filter, find, splitter;
import std.array: array, join;
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
    string path; /// path to the dub package
    string mainSourceFile;
    string targetFileName;
    string[] dflags;
    string[] lflags;
    string[] importPaths;
    string[] cImportPaths;
    string[] stringImportPaths;
    string[] files;
    TargetType targetType;
    string[] versions;
    string[] dependencies;
    string[] libs;
    string[] preBuildCommands;
    string[] postBuildCommands;
    string targetPath;

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

    // abstracts the compiler and returns a range of version flags
    auto versionFlags(in string compilerBinName) @safe pure const {
        import std.algorithm: map;

        const versionOpt = () {
            switch(compilerBinName) {
                default:
                    throw new Exception("Unknown compiler " ~ compilerBinName);
                case "dmd":
                case "gdc":
                    return "-version";
                case "ldc2":
                case "ldc":
                case "ldmd":
                case "ldmd2":
                    return "-d-version";
            }
        }();

        return versions.map!(a => versionOpt ~ "=" ~ a);
    }

    const(string)[] compilerFlags(in string compilerBinName) @safe pure const {
        import std.algorithm: among, startsWith;

        const(string)[] pkgDflags = dflags;
        if(compilerBinName.among("ldc", "ldc2")) {
            if (pkgDflags.length) {
                // For LDC, dub implicitly adds `--oq -od=…/obj` to avoid object-file collisions.
                // Remove that workaround for reggae; it's not needed and unexpected.
                foreach (i; 0 .. pkgDflags.length - 1) {
                    if (pkgDflags[i] == "--oq" && pkgDflags[i+1].startsWith("-od=")) {
                        pkgDflags = pkgDflags[0 .. i] ~ pkgDflags[i+2 .. $];
                        break;
                    }
                }
            }
        }

        return pkgDflags;
    }
}

bool isStaticLibrary(in string fileName) @safe pure nothrow {
    import std.path: extension;
    version(Windows)
        return fileName.extension == ".lib";
    else
        return fileName.extension == ".a";
}

bool isObjectFile(in string fileName) @safe pure nothrow {
    import reggae.rules.common: objExt;
    import std.path: extension;
    return fileName.extension == objExt;
}

string inDubPackagePath(in string packagePath, in string filePath) @safe pure nothrow {
    import std.algorithm: startsWith;
    return filePath.startsWith("$project")
        ? buildPath(filePath)
        : buildPath(packagePath, filePath);
}

struct DubObjsDir {
    string globalDir;
    string targetDir;
}

struct DubInfo {

    import reggae.rules.dub: CompilationMode;
    import reggae.options: Options;

    DubPackage[] packages;
    Options options;

    DubInfo dup() @safe pure nothrow const {
        import std.algorithm: map;
        import std.array: array;
        return DubInfo(packages.map!(a => a.dup).array);
    }

    Target[] toTargets(in CompilationMode compilationMode = CompilationMode.options,
                       in DubObjsDir dubObjsDir = DubObjsDir())
        @safe const
    {
        Target[] targets;

        foreach(i; 0 .. packages.length) {
            targets ~= packageIndexToTargets(i, compilationMode, dubObjsDir);
        }

        return targets ~ allObjectFileSources ~ allStaticLibrarySources;
    }

    // dubPackage[i] -> Target[]
    private Target[] packageIndexToTargets(
        in size_t dubPackageIndex,
        in CompilationMode compilationMode = CompilationMode.options,
        in DubObjsDir dubObjsDir = DubObjsDir())
        @safe const
    {
        import reggae.path: deabsolutePath;
        import std.range: chain, only;
        import std.algorithm: filter;
        import std.array: array, replace;
        import std.functional: not;
        import std.path: dirSeparator, baseName;
        import std.string: indexOf, stripRight;

        const dubPackage = packages[dubPackageIndex];
        const importPaths = dubPackage.packagePaths(
            dubPackage.importPaths ~ dubPackage.cImportPaths);
        const stringImportPaths = dubPackage.packagePaths(dubPackage.stringImportPaths);
        const isMainPackage = dubPackageIndex == 0;
        //the path must be explicit for the other packages, implicit for the "main"
        //package
        const projDir = isMainPackage ? "" : dubPackage.path;

        const allCompilerFlags = chain(
            dubPackage.compilerFlags(options.compilerBinName),
            dubPackage.versionFlags(options.compilerBinName),
            options.dflags,
        )
            .array;

        const srcFiles = dubPackage.files
            .filter!(not!isStaticLibrary)
            .filter!(not!isObjectFile)
            .map!(a => buildPath(dubPackage.path, a))
            .array;

        auto compileFunc() {
            import reggae.rules.d: dlangObjectFilesTogether,
                dlangObjectFilesPerModule, dlangObjectFilesPerPackage,
                dlangObjectFilesFunc;
            final switch(compilationMode) with(CompilationMode) {
                case all: return &dlangObjectFilesTogether;
                case module_: return &dlangObjectFilesPerModule;
                case package_: return &dlangObjectFilesPerPackage;
                case options: return dlangObjectFilesFunc(this.options);
            }
        }

        auto packageTargets = () {
            import reggae.rules.d: dlangStaticLibraryTogether;

            const isStaticLibDep =
                dubPackage.targetType == TargetType.staticLibrary &&
                !isMainPackage &&
                !options.dubDepObjsInsteadOfStaticLib;

            return isStaticLibDep
                ? dlangStaticLibraryTogether(options, srcFiles, allCompilerFlags, importPaths, stringImportPaths, [], projDir)
                : compileFunc()(options, srcFiles, allCompilerFlags, importPaths, stringImportPaths, [], projDir);
        }();

        const dubPkgRoot = buildPath(dubPackage.path).deabsolutePath.stripRight(dirSeparator);

        // adjust object file output paths for all dub projects
        // optionally put the object files in dubObjsDir
        if(dubObjsDir.globalDir != "") {
            const shortenedRoot = buildPath(dubObjsDir.globalDir, baseName(dubPackage.path));
            foreach(ref target; packageTargets) {
                import std.base64 : Base64URL;
                import std.digest.sha : sha256Of;

                const cmd = target.shellCommand(options);
                const string hashstr = Base64URL.encode(sha256Of(cmd)[0 .. $ / 2]).stripRight("=");
                const targetRoot = buildPath(shortenedRoot, hashstr);
                target.rawOutputs[0] = buildPath(target.rawOutputs[0]).replace(dubPkgRoot, targetRoot);
            }
        } else {
            const shortenedRoot = baseName(dubPackage.path);
            foreach(ref target; packageTargets)
                target.rawOutputs[0] = buildPath(target.rawOutputs[0]).replace(dubPkgRoot, shortenedRoot);
        }

        // shorten the object file output path for dub-generated dub_test_root.d
        // (only generated for the main package) in the cache dir (important on Windows)
        if (isMainPackage) {
            foreach(ref target; packageTargets) {
                const p = buildPath(target.rawOutputs[0]);
                const i = p.indexOf(dirSeparator ~ "__dub_cache__" ~ dirSeparator);
                if (i > 0)
                    target.rawOutputs[0] = p[i + 1 .. $];
            }
        }

        return packageTargets;
    }

    TargetName targetName() @safe const pure nothrow {
        const fileName = packages[0].targetFileName;
        return .targetName(targetType, fileName);
    }

    string targetPath(in Options options) @safe const pure {
        import std.path: relativePath;

        return options.workingDir == options.projectPath
            ? packages[0].targetPath.relativePath(options.projectPath)
            : "";
    }

    TargetType targetType() @safe const pure nothrow {
        return packages[0].targetType;
    }

    string[] linkerFlags() @safe pure nothrow const {
        const allLibs = packages[0].libs;

        static string libFlag(in string lib) {
            version(Posix)
                return "-L-l" ~ lib;
            else
                return lib ~ ".lib";
        }

        return
            packages[0].libs.map!libFlag.array ~
            packages[0].lflags.dup
            ;
    }

    // must be at the very end
    private Target[] allStaticLibrarySources() @trusted /*join*/ nothrow const pure {
        import std.algorithm: filter, map;
        import std.array: array, join;

        return packages
            .map!(a => cast(string[]) a.files.filter!isStaticLibrary.array)
            .join
            .map!(a => Target(a))
            .array;
    }

    private Target[] allObjectFileSources() @trusted nothrow const pure {
        import std.algorithm.iteration: filter, map, uniq;
        import std.algorithm.sorting: sort;
        import std.array: array, join;

        string[] objectFiles =
        packages
            .map!(a => cast(string[]) a
                  .files
                  .filter!isObjectFile
                  .map!(b => inDubPackagePath(a.path, b))
                  .array
            )
            .join
            .array;
        sort(objectFiles);

        return objectFiles
            .uniq
            .map!(a => Target(a))
            .array;
    }


    // all postBuildCommands in one shell command. Empty if there are none
    string postBuildCommands() @safe pure nothrow const {
        import std.string: join;
        return packages[0].postBuildCommands.join(" && ");
    }
}


private string[] packagePaths(in DubPackage dubPackage, in string[] paths) @trusted nothrow {
    return paths.map!(a => buildPath(dubPackage.path, a)).array;
}


TargetName targetName(in TargetType targetType, in string fileName) @safe pure nothrow {

    import reggae.rules.common: exeExt;

    switch(targetType) with(TargetType) {
    default:
        return TargetName(fileName);

    case executable:
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
