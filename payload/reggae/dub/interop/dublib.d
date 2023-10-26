/**
   Extract build information by using dub as a library
 */
module reggae.dub.interop.dublib;


import dub.generators.generator: ProjectGenerator;

// to avoid using it in the wrong way
package:

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
    private const string[] _extraDFlags;
    private const(Options) _options;

    this(in Options options) @safe {
        import reggae.path: buildPath;
        import std.exception: enforce;
        import std.file: exists;

        _options = options;

        const path = buildPath(options.projectPath, "dub.selections.json");
        enforce(path.exists, "Cannot create dub instance without dub.selections.json");

        _project = project(ProjectPath(options.projectPath));
        _extraDFlags = options.dflags.dup;
    }

    const(Options) options() @safe @nogc pure nothrow const return scope {
        return _options;
    }

    auto getPackage(in string dubPackage, in string version_) @trusted /*dub*/ {
        import dub.dependency: Version;
        return _project.packageManager.getPackage(dubPackage, Version(version_));
    }

    private static auto getGeneratorSettings(in Options options) {
        import dub.compilers.compiler: getCompiler;
        import dub.generators.generator: GeneratorSettings;
        import dub.internal.vibecompat.inet.path: NativePath;
        import std.path: baseName, stripExtension;

        const compilerBinName = options.dCompiler.baseName.stripExtension;

        GeneratorSettings ret;

        ret.cache = NativePath(options.workingDir) ~ "__dub_cache__";
        ret.compiler = () @trusted { return getCompiler(compilerBinName); }();
        ret.platform = () @trusted {
            return ret.compiler.determinePlatform(ret.buildSettings,
                options.dCompiler, options.dubArchOverride);
        }();
        ret.buildType = options.dubBuildType;

        return ret;
    }

    DubConfigurations getConfigs() {
        import std.algorithm: filter, map, canFind;
        import std.array: array;
        import std.conv: text;

        auto singleConfig = _options.dubConfig;
        auto settings = getGeneratorSettings(_options);
        const allConfigs = singleConfig == "";
        // add the special `dub test` configuration (which doesn't require an existing `unittest` config)
        const lookingForUnitTestsConfig = allConfigs || singleConfig == "unittest";
        const testConfig = lookingForUnitTestsConfig
            ? _project.addTestRunnerConfiguration(settings)
            : null; // skip when requesting a single non-unittest config

        // error out if the test config is explicitly requested but not available
        if(_options.dubConfig == "unittest" && testConfig == "") {
            throw new Exception("No dub test configuration available (target type 'none'?)");
        }

        const haveSpecialTestConfig = testConfig.length && testConfig != "unittest";
        const defaultConfig = _project.getDefaultConfiguration(settings.platform);

        // A violation of the Law of Demeter caused by a dub bug.
        // Otherwise _project.configurations would do, but it fails for one
        // projet and no reduced test case was found.
        auto allConfigurationsAsStrings =
            _project
            .rootPackage
            .recipe
            .configurations
            .filter!(c => c.matchesPlatform(settings.platform))
            .map!(c => c.name)
            ;

        if (!allConfigs) { // i.e. one single config specified by the user
            // translate `unittest` to the actual test configuration
            const requestedConfig = haveSpecialTestConfig ? testConfig : singleConfig;


            const canFindConfig = allConfigurationsAsStrings.save.canFind(requestedConfig);
            if (!canFindConfig && requestedConfig != "default")
                throw new Exception(
                    text("Unknown dub configuration `", requestedConfig, "` - known configurations:\n    ",
                         allConfigurationsAsStrings.save)
                );
            // if the user requests "default", then give them the
            // first available configuration, whether or not it's
            // actually called "default".
            assert(canFindConfig || requestedConfig == "default");
            const actualConfig = canFindConfig
                ? requestedConfig
                : defaultConfig;

            return DubConfigurations([actualConfig], actualConfig, testConfig);
        }

        // A violation of the Law of Demeter caused by a dub bug.
        // Otherwise _project.configurations would do, but it fails for one
        // projet and no reduced test case was found.
        auto configurations = allConfigurationsAsStrings
            .save
            // exclude unittest config if there's a derived special one
            .filter!(n => !haveSpecialTestConfig || n != "unittest")
            .array;

        return DubConfigurations(configurations, defaultConfig, testConfig);
    }

    DubInfo configToDubInfo(in string config = "") @trusted /*dub*/ {
        auto generator = new InfoGenerator(_project, _extraDFlags);
        auto settings = getGeneratorSettings(_options);
        settings.config = config;
        generator.generate(settings);
        return DubInfo(generator.dubPackages, _options.dup);
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
    private const string[] _extraDFlags;

    this(Project project, const string[] extraDFlags) @trusted {
        super(project);
        _extraDFlags = extraDFlags;
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
                "cImportPaths", "stringImportPaths", "versions", "libs",
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

    private void adjustMainPackage(ref DubPackage pkg,
                                   in GeneratorSettings settings,
                                   in BuildSettings buildSettings) const
    {
        import dub.compilers.dmd: DMDCompiler;
        import dub.compilers.ldc: LDCCompiler;
        import std.algorithm.searching: canFind, startsWith;
        import std.algorithm.iteration: filter, map;
        import std.array: array;
        import std.range: chain;

        // this is copied from dub's DMDCompiler.invokeLinker since
        // unfortunately that function modifies the arguments before
        // calling the linker, but we can't call it either since it
        // has side-effects. Until dub gets refactored, this has to
        // be maintained in parallel. Sigh.

        pkg.lflags = pkg.lflags.map!(a => "-L" ~ a).array;

        if(settings.platform.platform.canFind("linux"))
            pkg.lflags = "-L--no-as-needed" ~ pkg.lflags;

        auto dflags = buildSettings.dflags.chain(_extraDFlags);
        pkg.lflags ~= settings.platform.compiler == "ldc"
            ? dflags.filter!(LDCCompiler.isLinkerDFlag).array // ldc2 / ldmd2
            : dflags.filter!(DMDCompiler.isLinkerDFlag).array;
    }
}
