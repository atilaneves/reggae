module reggae.rules.cmake;

imported!"reggae.build".Target[] cmakeBuild(imported!"reggae.types".ProjectPath projectPath,
                                            imported!"reggae.rules.dub".Configuration cmakeConfig = imported!"reggae.rules.dub".Configuration("Release"),
                                            imported!"reggae.types".TargetName[] targetNames = [],
                                            imported!"reggae.types".CMakeFlags cmakeFlags = imported!"reggae.types".CMakeFlags())() {
    import reggae.types : TargetName;
    import std.exception : enforce;
    import std.algorithm : filter, map, canFind;
    import std.array : array;
    import std.range : empty, walkLength;
    import std.json : JSONValue;
    import std.path : buildNormalizedPath;
    import std.stdio : stderr, writeln;

    auto cmakeInfo = queryFileApi(projectPath.value, cmakeFlags);

    auto configurations = cmakeInfo
        .codeModel["configurations"]
        .array
        .filter!(c => c["name"].str == cmakeConfig.value);

    enforce(configurations.walkLength == 1,
            "Could not find configuration '" ~ cmakeConfig.value ~ "'");

    const configuration = configurations.front;

    const cmakeTargetEntries = configuration["targets"].array;
    const selectedCMakeTargetEntries = targetNames.empty
        ? cmakeTargetEntries
        : cmakeTargetEntries.filter!(target => targetNames.canFind(TargetName(target["name"].str)))
                            .array;

    auto selectedCMakeTargets = selectedCMakeTargetEntries.map!((targetEntry) {
        const targetJsonFile = targetEntry["jsonFile"].str;
        return readJson(buildNormalizedPath(cmakeInfo.apiReplyDir, targetJsonFile));
    });

    return selectedCMakeTargets.filter!((target) {
        if (target["type"].str.isSupportedTarget) {
            return true;
        }
        stderr.writeln("[WARNING] Skipping unsupported target '" ~ target["name"].str ~
                       "' of type '" ~ target["type"].str ~ "'");
        return false;
    }).map!(t => t.toReggaeTarget(cmakeInfo)).array;
}

private imported!"std.json".JSONValue readJson(in string path) {
    import std.file : readText;
    import std.json : parseJSON;
    return path.readText.parseJSON;
}

private string findJsonFilePath(in string apiReplyDir, in string name) {
    import std.exception : enforce;
    import std.array : array;
    import std.path : baseName, extension;
    import std.file : dirEntries, SpanMode;
    import std.algorithm : map, filter, startsWith;

    auto files = dirEntries(apiReplyDir, SpanMode.shallow)
                 .map!(de => de.name)
                 .filter!(f => f.baseName.startsWith(name) && f.extension == ".json")
                 .array;

    enforce(files.length == 1, "Could not find the '" ~ name ~ "' JSON file.");
    return files[0];
}

private enum SourceLanguage : string {
    C = "C",
    CPP = "CXX",
}

private bool isSupportedLanguage(in string lang) {
    import std.traits : EnumMembers;
    import std.algorithm : canFind;
    return [EnumMembers!SourceLanguage].canFind(lang);
}

private struct CompileOptions {
    import reggae.types : Flags, IncludePaths;
    Flags compilerFlags;
    IncludePaths includes;
    SourceLanguage language;
}

private CompileOptions getCompileOptions(in imported!"std.json".JSONValue targetJsonObj, ulong compileGroupIndex) {
    import std.format : format;
    import std.exception : enforce;
    import std.array : join, array;
    import std.algorithm : map;

    auto compileGroups = targetJsonObj["compileGroups"].array;
    enforce(compileGroups.length > compileGroupIndex, "Index out of bounds.");

    auto compileGroup = compileGroups[compileGroupIndex];
    const language = compileGroup["language"].str;
    enforce(isSupportedLanguage(language), "'%s' is not supported.".format(language));

    immutable notSupportedFeatures = ["precompileHeaders"];
    foreach (feature; notSupportedFeatures) {
        enforce(feature !in compileGroup, "The '" ~ feature ~ "' is not supported.");
    }

    static CompileOptions getCompileOptionsImpl(in imported!"std.json".JSONValue compileGroup, ulong groupIndex) {
        import reggae.types : IncludePaths, Flags;

        static CompileOptions[ulong] groupIndexToOptions;

        if (auto opt = groupIndex in groupIndexToOptions) {
            return *opt;
        }

        version(Windows) {
            enum defineFlag = "/D";
        } else {
            enum defineFlag = "-D";
        }

        string defines;
        if ("defines" in compileGroup) {
            defines = compileGroup["defines"].array
                            .map!(def => defineFlag ~ def["define"].str)
                            .join(" ");
        }

        string compileCommand;
        if ("compileCommandFragments" in compileGroup) {
            compileCommand = compileGroup["compileCommandFragments"].array
                                    .map!(frag => frag["fragment"].str)
                                    .join(" ");
        }

        IncludePaths includes;
        if ("includes" in compileGroup) {
            includes = compileGroup["includes"].array
                                    .map!(incl => incl["path"].str)
                                    .array.IncludePaths;
        }
        return groupIndexToOptions[groupIndex] = CompileOptions(Flags(defines ~ " " ~ compileCommand),
                                                                includes,
                                                                cast(SourceLanguage) compileGroup["language"].str);
    }
    return getCompileOptionsImpl(compileGroup, compileGroupIndex);
}

private bool isCppHeader(in string file) {
    import std.path : extension;
    string ext = file.extension;
    return ext == ".hpp" || ext == ".hxx" || ext == ".H";
}

private bool isCHeader(in string file) {
    import std.path : extension;
    return file.extension == ".h";
}

private bool isHeaderFile(in string file) {
    return isCHeader(file) || isCppHeader(file);
}

private string getLinkerFlags(in imported!"std.json".JSONValue target) {
    import std.array : join;
    import std.algorithm : each;

    string flags, libraries, libraryPath;

    if ("link" !in target) {
        return null;
    }

    version(Windows) {
        enum libPathFlag = "/LIBPATH:";
    } else {
        enum libPathFlag = "-L";
    }

    auto link = target["link"];
    link["commandFragments"].array.each!((cf) {
        switch(cf["role"].str) {
            case "flags":
                flags ~= cf["fragment"].str ~ " ";
                break;
            case "libraries":
                libraries ~= cf["fragment"].str ~ " ";
                break;
            case "libraryPath":
                libraryPath ~= libPathFlag ~ cf["fragment"].str ~ " ";
                break;
            default:
                throw new Exception("Linker flag of type '" ~ cf["role"].str ~ "' is not supported.");
        }
    });

    return [flags, libraries, libraryPath].join(" ");
}

private enum TargetType : string {
    Executable = "EXECUTABLE",
    StaticLib = "STATIC_LIBRARY",
    SharedLib = "SHARED_LIBRARY",
}

private bool isSupportedTarget(in string target) {
    import std.traits : EnumMembers;
    import std.algorithm : canFind;
    return [EnumMembers!TargetType].canFind(target);
}

private imported!"reggae.build".Target toReggaeTarget(in imported!"std.json".JSONValue target,
                                                      CMakeInfo cmakeInfo) {
    import reggae.config: options;
    import reggae.rules.common : objectFile, link, staticLibraryTarget;
    import reggae.build : Target;
    import reggae.types : SourceFile, ExeName, Flags;
    import std.format : format;
    import std.exception : enforce;
    import std.path : buildNormalizedPath, isAbsolute, baseName;
    import std.algorithm : filter;
    import std.range : walkLength;
    import std.stdio : writeln, stderr;

    const sourceDir = cmakeInfo.codeModel["paths"]["source"].str;

    Target[] intermediateTargets;

    foreach (sourceJsonObj; target["sources"].array) {
        const filePath = sourceJsonObj["path"].str;
        const sourceFilePath = filePath.isAbsolute ? filePath : buildNormalizedPath(sourceDir, filePath);

        const needsToBeCompiled = "compileGroupIndex" in sourceJsonObj;
        if (!needsToBeCompiled) {
            enforce(sourceFilePath.isHeaderFile,
                    "File '%s' which is neither compiled nor a header is not supported.".format(sourceFilePath));
            continue;
        }

        const compileGroupIndex = sourceJsonObj["compileGroupIndex"].integer;
        auto compileOptions = target.getCompileOptions(compileGroupIndex);

        intermediateTargets ~= objectFile(options,
                                          SourceFile(sourceFilePath),
                                          compileOptions.compilerFlags,
                                          compileOptions.includes);
    }

    enforce(target["type"].str.isSupportedTarget,
            "Target type '%s' not supported.".format(target["type"].str));

    auto artifacts = target["artifacts"].array;
    enforce(artifacts.length >= 1, "Supported targets must generate at least one artifact.");
    if (artifacts.length > 1) {
        stderr.writeln("[Warning] Target '" ~ target["name"].str ~ "' generates multiple artifacts.");
    }
    const artifactPath = buildNormalizedPath(options.workingDir, target["nameOnDisk"].str);

    const targetType = cast(TargetType) target["type"].str;
    final switch (targetType) with (TargetType) {
        case SharedLib:
            goto case Executable;

        case Executable:
            return link(ExeName(artifactPath), intermediateTargets, Flags(target.getLinkerFlags));

        case StaticLib:
            return staticLibraryTarget(artifactPath, intermediateTargets);
    }
}

private struct CMakeInfo {
    import std.json : JSONValue;
    JSONValue codeModel;
    string apiReplyDir;
    JSONValue toolchain;
}

private CMakeInfo queryFileApi(in string projectPath, imported!"reggae.types".CMakeFlags cmakeFlags) {
    import std.process : executeShell;
    import std.exception : enforce;
    import std.path : extension, buildNormalizedPath, baseName;
    import std.file : tempDir, exists, mkdirRecurse, rmdirRecurse;
    import std.stdio : File;

    const buildDir = buildNormalizedPath(tempDir, projectPath.baseName ~ "-build");
    if (buildDir.exists)
        buildDir.rmdirRecurse;
    buildDir.mkdirRecurse;

    // Specify the path to the CMake File API v1 directory
    const apiDir = buildNormalizedPath(buildDir, ".cmake/api/v1/");
    const apiQueryDir = buildNormalizedPath(apiDir, "query");

    if (!apiQueryDir.exists)
        apiQueryDir.mkdirRecurse;

    // Query codemodel-v2
    File(buildNormalizedPath(apiQueryDir, "codemodel-v2"), "w");

    // Query toolchains
    File(buildNormalizedPath(apiQueryDir, "toolchains-v1"), "w");

    // Run CMake to generate the reply files
    const cmakeCommand = "cmake -B " ~ buildDir ~ " " ~ cmakeFlags.value;
    auto process = executeShell(cmakeCommand, workDir : projectPath);
    enforce(process.status == 0, "Couldn't run CMake to query File API.");

    // Look for the reply index file in the reply directory
    const apiReplyDir = buildNormalizedPath(apiDir, "reply");

    // Check if the reply index file exists
    enforce(apiReplyDir.exists, "CMake did not generate any reply.");

    return CMakeInfo(
            readJson(apiReplyDir.findJsonFilePath("codemodel-v2")),
            apiReplyDir,
            readJson(apiReplyDir.findJsonFilePath("toolchains-v1")));
}
