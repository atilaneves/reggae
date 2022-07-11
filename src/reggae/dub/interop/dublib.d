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
        ret.platform = () @trusted {
            return ret.compiler.determinePlatform(ret.buildSettings,
                options.dCompiler, options.dubArchOverride);
        }();
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
    override void generateTargets(GeneratorSettings settings,
                                  in TargetInfo[string] targets)
        @trusted
    {

        import dub.compilers.buildsettings: BuildSetting;
        import std.file: exists, mkdirRecurse;

        DubPackage nameToDubPackage(in string targetName,
                                    in bool isFirstPackage = false)
        {
            const targetInfo = targets[targetName];
            auto newBuildSettings = targetInfo.buildSettings.dup;
            settings.compiler.prepareBuildSettings(newBuildSettings,
                                                   settings.platform,
                                                   BuildSetting.noOptions /*???*/);
            DubPackage pkg;

            pkg.name = targetInfo.pack.name;
            pkg.path = targetInfo.pack.path.toNativeString;
            pkg.targetFileName = newBuildSettings.targetName;
            pkg.targetPath = newBuildSettings.targetPath;

            // this needs to be done here so as to happen before
            // dub.generators.generator.finalizeGeneration so that copyFiles
            // can work
            if(!pkg.targetPath.exists) mkdirRecurse(pkg.targetPath);

            pkg.files = newBuildSettings.sourceFiles.dup;
            pkg.targetType = cast(typeof(pkg.targetType)) newBuildSettings.targetType;
            pkg.dependencies = targetInfo.dependencies.dup;

            enum sameNameProperties = [
                "mainSourceFile", "dflags", "lflags", "importPaths",
                "stringImportPaths", "versions", "libs",
            ];
            static foreach(prop; sameNameProperties) {
                mixin(`pkg.`, prop, ` = newBuildSettings.`, prop, `;`);
            }

            // {pre,post}BuildCommands: need to manually replace variables since dub v1.29
            static foreach (xBuild; ["preBuild", "postBuild"]) {{
                const rawCmds = mixin("newBuildSettings."~xBuild~"Commands");
                if (rawCmds.length) {
                    import dub.generators.generator: makeCommandEnvironmentVariables, CommandType;
                    import dub.project: processVars;
                    const env = makeCommandEnvironmentVariables(mixin("CommandType."~xBuild), targetInfo.pack, m_project, settings, newBuildSettings);
                    mixin("pkg."~xBuild~"Commands") = processVars(m_project, targetInfo.pack, settings, rawCmds, false, env);
                }
            }}

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
        import dub.compilers.dmd: DMDCompiler;
        import dub.compilers.ldc: LDCCompiler;
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

        pkg.lflags ~= settings.platform.compiler == "ldc"
            ? buildSettings.dflags.filter!(LDCCompiler.isLinkerDFlag).array // ldc2 / ldmd2
            : buildSettings.dflags.filter!(DMDCompiler.isLinkerDFlag).array;
    }
}
