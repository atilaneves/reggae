/**
   Extract build information by using dub as a library
 */
module reggae.dub.interop.dublib;


import reggae.from;
import dub.generators.generator: ProjectGenerator;


// Not shared because, for unknown reasons, dub registers compilers
// in thread-local storage so we register the compilers in all
// threads. In normal dub usage it's done in of one dub's static
// constructors. In one thread.
static this() nothrow {
    import dub.compilers.compiler: registerCompiler;
    import dub.compilers.dmd: DMDCompiler;
    import dub.compilers.ldc: LDCCompiler;
    import dub.compilers.gdc: GDCCompiler;

    try {
        registerCompiler(new DMDCompiler);
        registerCompiler(new LDCCompiler);
        registerCompiler(new GDCCompiler);
    } catch(Exception e) {
        import std.stdio: stderr;
        try
            stderr.writeln("ERROR: ", e);
        catch(Exception _) {}
    }
}


struct Dub {
    import reggae.dub.interop.configurations: DubConfigurations;
    import reggae.dub.info: DubInfo;
    import reggae.options: Options;
    import dub.project: Project;

    private Project _project;

    this(in Options options) @safe {
        import reggae.path: buildPath;
        import std.exception: enforce;
        import std.file: exists;

        const path = buildPath(options.projectPath, "dub.selections.json");
        enforce(path.exists, "Cannot create dub instance without dub.selections.json");

        _project = project(ProjectPath(options.projectPath));
    }

    auto getPackage(in string dubPackage, in string version_) @trusted /*dub*/ {
        import dub.dependency: Version;
        return _project.packageManager.getPackage(dubPackage, Version(version_));
    }

    static auto getGeneratorSettings(in Options options) {
        import dub.compilers.compiler: getCompiler;
        import dub.generators.generator: GeneratorSettings;
        import std.path: baseName, stripExtension;

        const compilerBinName = options.dCompiler.baseName.stripExtension;

        GeneratorSettings ret;

        ret.compiler = () @trusted { return getCompiler(compilerBinName); }();
        ret.platform = () @trusted { return ret.compiler.determinePlatform(ret.buildSettings, options.dCompiler); }();
        ret.buildType = options.dubBuildType;

        return ret;
    }

    DubConfigurations getConfigs(/*in*/ ref from!"dub.platform".BuildPlatform platform) {

        import std.algorithm.iteration: filter, map;
        import std.array: array;

        // A violation of the Law of Demeter caused by a dub bug.
        // Otherwise _project.configurations would do, but it fails for one
        // projet and no reduced test case was found.
        auto configurations = _project
            .rootPackage
            .recipe
            .configurations
            .filter!(c => c.matchesPlatform(platform))
            .map!(c => c.name)
            .array;

        // Project.getDefaultConfiguration() requires a mutable arg (forgotten `in`)
        return DubConfigurations(configurations, _project.getDefaultConfiguration(platform));
    }

    DubInfo configToDubInfo
    (from!"dub.generators.generator".GeneratorSettings settings, in string config)
        @trusted  // dub
    {
        auto generator = new InfoGenerator(_project);
        settings.config = config;
        generator.generate(settings);
        return DubInfo(generator.dubPackages);
    }

    void reinit() @trusted {
        _project.reinit;
    }
}


/// What it says on the tin
struct ProjectPath {
    string value;
}

/// Normally ~/.dub
struct UserPackagesPath {
    string value = "/dev/null";
}

/// Normally ~/.dub
UserPackagesPath userPackagesPath() @safe {
    import reggae.path: buildPath;
    import std.process: environment;
    import std.path: isAbsolute;
    import std.file: getcwd;

    version(Windows) {
        immutable appDataDir = environment.get("APPDATA");
        const path = buildPath(environment.get("LOCALAPPDATA", appDataDir), "dub");
    } else version(Posix) {
        string path = buildPath(environment.get("HOME"), ".dub/");
        if(!path.isAbsolute)
            path = buildPath(getcwd(), path);
    } else
          static assert(false, "Unknown system");

    return UserPackagesPath(path);
}

struct SystemPackagesPath {
    string value = "/dev/null";
}


SystemPackagesPath systemPackagesPath() @safe {
    import reggae.path: buildPath;
    import std.process: environment;

    version(Windows)
        const path = buildPath(environment.get("ProgramData"), "dub/");
    else version(Posix)
        const path = "/var/lib/dub/";
    else
        static assert(false, "Unknown system");

    return SystemPackagesPath(path);
}


struct Path {
    string value;
}

struct JSONString {
    string value;
}


struct DubPackages {

    import dub.packagemanager: PackageManager;

    private PackageManager _packageManager;
    private string _userPackagesPath;

    this(in ProjectPath projectPath,
         in SystemPackagesPath systemPackagesPath,
         in UserPackagesPath userPackagesPath)
        @safe
    {
        _packageManager = packageManager(projectPath, systemPackagesPath, userPackagesPath);
        _userPackagesPath = userPackagesPath.value;
    }

    /**
       Takes a path to a zipped dub package and stores it in the appropriate
       user packages path.
       The metadata is usually taken from the dub registry via an HTTP
       API call.
     */
    void storeZip(in Path zip, in JSONString metadata) @safe {
        import dub.internal.vibecompat.data.json: parseJson;
        import dub.internal.vibecompat.inet.path: NativePath;
        import reggae.path: buildPath;

        auto metadataString = metadata.value.idup;
        auto metadataJson = () @trusted { return parseJson(metadataString); }();
        const name = () @trusted { return cast(string) metadataJson["name"]; }();
        const version_ = () @trusted { return cast(string) metadataJson["version"]; }();

        () @trusted {
            _packageManager.storeFetchedPackage(
                NativePath(zip.value),
                metadataJson,
                NativePath(buildPath(_userPackagesPath, "packages", name ~ "-" ~ version_, name)),
            );
        }();
    }
}


auto project(in ProjectPath projectPath) @safe {
    return project(projectPath, systemPackagesPath, userPackagesPath);
}


auto project(in ProjectPath projectPath,
             in SystemPackagesPath systemPackagesPath,
             in UserPackagesPath userPackagesPath)
    @trusted
{
    import dub.project: Project;
    import dub.internal.vibecompat.inet.path: NativePath;

    auto pkgManager = packageManager(projectPath, systemPackagesPath, userPackagesPath);

    return new Project(pkgManager, NativePath(projectPath.value));
}


private auto dubPackage(in ProjectPath projectPath) @trusted {
    import dub.internal.vibecompat.inet.path: NativePath;
    import dub.package_: Package;
    return new Package(recipe(projectPath), NativePath(projectPath.value));
}


private auto recipe(in ProjectPath projectPath) @safe {
    import dub.recipe.packagerecipe: PackageRecipe;
    import dub.recipe.json: parseJson;
    import dub.recipe.sdl: parseSDL;
    static import dub.internal.vibecompat.data.json;
    import std.file: readText, exists;

    PackageRecipe recipe;

    string inProjectPath(in string path) {
        import reggae.path: buildPath;
        return buildPath(projectPath.value, path);
    }

    if(inProjectPath("dub.sdl").exists) {
        const text = readText(inProjectPath("dub.sdl"));
        () @trusted { parseSDL(recipe, text, "parent", "dub.sdl"); }();
        return recipe;
    } else if(inProjectPath("dub.json").exists) {
        auto text = readText(inProjectPath("dub.json"));
        auto json = () @trusted { return dub.internal.vibecompat.data.json.parseJson(text); }();
        () @trusted { parseJson(recipe, json, "" /*parent*/); }();
        return recipe;
    } else
        throw new Exception("Could not find dub.sdl or dub.json in " ~ projectPath.value);
}


auto packageManager(in ProjectPath projectPath,
                    in SystemPackagesPath systemPackagesPath,
                    in UserPackagesPath userPackagesPath)
    @trusted
{
    import dub.internal.vibecompat.inet.path: NativePath;
    import dub.packagemanager: PackageManager;

    const packagePath = NativePath(projectPath.value);
    const userPath = NativePath(userPackagesPath.value);
    const systemPath = NativePath(systemPackagesPath.value);
    const refreshPackages = false;

    auto pkgManager = new PackageManager(packagePath, userPath, systemPath, refreshPackages);
    // In dub proper, this initialisation is done in commandline.d
    // in the function runDubCommandLine. If not not, subpackages
    // won't work.
    pkgManager.getOrLoadPackage(packagePath);

    return pkgManager;
}


class InfoGenerator: ProjectGenerator {
    import reggae.dub.info: DubPackage;
    import dub.project: Project;
    import dub.generators.generator: GeneratorSettings;
    import dub.compilers.buildsettings: BuildSettings;

    DubPackage[] dubPackages;

    this(Project project) @trusted {
        super(project);
    }

    /** Copied from the dub documentation:

        Overridden in derived classes to implement the actual generator functionality.

        The function should go through all targets recursively. The first target
        (which is guaranteed to be there) is
        $(D targets[m_project.rootPackage.name]). The recursive descent is then
        done using the $(D TargetInfo.linkDependencies) list.

        This method is also potentially responsible for running the pre and post
        build commands, while pre and post generate commands are already taken
        care of by the $(D generate) method.

        Params:
            settings = The generator settings used for this run
            targets = A map from package name to TargetInfo that contains all
                binary targets to be built.
    */
    override void generateTargets(GeneratorSettings settings, in TargetInfo[string] targets) @trusted {

        import dub.compilers.buildsettings: BuildSetting;

        DubPackage nameToDubPackage(in string targetName, in bool isFirstPackage = false) {
            const targetInfo = targets[targetName];
            auto newBuildSettings = targetInfo.buildSettings.dup;
            settings.compiler.prepareBuildSettings(newBuildSettings,
                                                   settings.platform,
                                                   BuildSetting.noOptions /*???*/);
            DubPackage pkg;

            pkg.name = targetInfo.pack.name;
            pkg.path = targetInfo.pack.path.toNativeString;
            pkg.targetFileName = newBuildSettings.targetName;
            pkg.files = newBuildSettings.sourceFiles.dup;
            pkg.targetType = cast(typeof(pkg.targetType)) newBuildSettings.targetType;
            pkg.dependencies = targetInfo.dependencies.dup;

            enum sameNameProperties = [
                "mainSourceFile", "dflags", "lflags", "importPaths",
                "stringImportPaths", "versions", "libs",
                "preBuildCommands", "postBuildCommands",
            ];
            static foreach(prop; sameNameProperties) {
                mixin(`pkg.`, prop, ` = newBuildSettings.`, prop, `;`);
            }

            if(isFirstPackage)  // unfortunately due to dub's `invokeLinker`
                adjustMainPackage(pkg, settings, newBuildSettings);

            return pkg;
        }


        bool[string] visited;

        const rootName = m_project.rootPackage.name;
        dubPackages ~= nameToDubPackage(rootName, true);

        foreach(i, dep; targets[rootName].linkDependencies) {
            if (dep in visited) continue;
            visited[dep] = true;
            dubPackages ~= nameToDubPackage(dep);
        }
    }

    private static adjustMainPackage(ref DubPackage pkg,
                                     in GeneratorSettings settings,
                                     in BuildSettings buildSettings)
    {
        import std.algorithm.searching: canFind, startsWith;
        import std.algorithm.iteration: filter, map;
        import std.array: array;

        // this is copied from dub's DMDCompiler.invokeLinker since
        // unfortunately that function modifies the arguments before
        // calling the linker, but we can't call it either since it
        // has side-effects. Until dub gets refactored, this has to
        // be maintained in parallel. Sigh.

        pkg.lflags = pkg.lflags.map!(a => "-L" ~ a).array;

        if(settings.platform.platform.canFind("linux"))
            pkg.lflags = "-L--no-as-needed" ~ pkg.lflags;

        // TODO: these can probably be used from dub's {DMD,LDC}Compiler class
        //       when bumping the dub dependency to v1.25 (dlang/dub#2082)
        static bool isLinkerDFlag_DMD(string arg) {
            switch (arg) {
            default:
                if (arg.startsWith("-defaultlib=")) return true;
                return false;
            case "-g", "-gc", "-m32", "-m64", "-shared", "-lib", "-m32mscoff":
                return true;
            }
        }
        static bool isLinkerDFlag_LDC(string arg) {
            // extra addition for ldmd2
            if (arg == "-m32mscoff")
                return true;

            if (arg.length > 2 && arg.startsWith("--"))
                arg = arg[1 .. $]; // normalize to 1 leading hyphen

            switch (arg) {
                case "-g", "-gc", "-m32", "-m64", "-shared", "-lib",
                     "-betterC", "-disable-linker-strip-dead", "-static":
                    return true;
                default:
                    return arg.startsWith("-L")
                        || arg.startsWith("-Xcc=")
                        || arg.startsWith("-defaultlib=")
                        || arg.startsWith("-platformlib=")
                        || arg.startsWith("-flto")
                        || arg.startsWith("-fsanitize=")
                        || arg.startsWith("-link-")
                        || arg.startsWith("-linker=")
                        || arg.startsWith("-march=")
                        || arg.startsWith("-mscrtlib=")
                        || arg.startsWith("-mtriple=");
            }
        }

        pkg.lflags ~= settings.platform.compiler == "ldc"
            ? buildSettings.dflags.filter!isLinkerDFlag_LDC.array // ldc2 / ldmd2
            : buildSettings.dflags.filter!isLinkerDFlag_DMD.array;
    }
}
