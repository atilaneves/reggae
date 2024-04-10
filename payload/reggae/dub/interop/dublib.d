/**
   Extract build information by using dub as a library
 */
module reggae.dub.interop.dublib;

version(Have_dub):
// to avoid using it in the wrong way
private:

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

private struct DubConfigurations {
    string[] configurations;
    string default_;
    string test; // special `dub test` config

    bool haveTestConfig() @safe @nogc pure nothrow scope const {
        return test != "";
    }

    bool isTestConfig(in string config) @safe @nogc pure nothrow scope const {
        return haveTestConfig && config == test;
    }
}

package struct Dub {
    import reggae.dub.info: DubInfo;
    import reggae.options: Options;
    import dub.dub: DubClass = Dub;
    import dub.generators.generator: GeneratorSettings;

    private DubClass _dub;
    private const string[] _extraDFlags;
    private const(Options) _options;
    private GeneratorSettings _generatorSettings;

    this(in Options options) @trusted {
        import reggae.path: buildPath;
        import std.exception: enforce;
        import std.file: exists;

        _options = options;
        _dub = fullDub(options.projectPath);
        _extraDFlags = options.dflags.dup;
        _generatorSettings = getGeneratorSettings(options);
    }

    const(Options) options() @safe @nogc pure nothrow const return scope {
        return _options;
    }

    void fetchDeps(O)(ref O output) {
        import reggae.io: log;
        import dub.dub: UpgradeOptions;

        if (!_dub.project.hasAllDependencies) {
            output.log("Fetching dub dependencies");
            _dub.upgrade(UpgradeOptions.select);
            output.log("Dub dependencies fetched");
        }
    }

    imported!"reggae.dub.info".DubInfo[string] getDubInfos(O)(ref O output)
    {
        import reggae.io: log;
        import reggae.path: buildPath;
        import reggae.dub.info: DubInfo;
        import std.file: exists;
        import std.exception: enforce;

        DubInfo[string] ret;

        const configs = dubConfigurations(output);
        bool atLeastOneConfigOk;
        Exception dubInfoFailure;

        foreach(config; configs.configurations) {
            try {
                ret[config] = configToDubInfo(output, config, configs.isTestConfig(config));
                atLeastOneConfigOk = true;
            } catch(Exception ex) {
                output.log("ERROR: Could not get info for configuration ", config, ": ", ex.msg);
                if(dubInfoFailure is null) dubInfoFailure = ex;
            }
        }

        if(!atLeastOneConfigOk) {
            assert(dubInfoFailure !is null,
                   "Internal error: no configurations worked and no exception to throw");
            throw dubInfoFailure;
        }

        ret["default"] = ret[configs.default_];

        // (additionally) expose the special `dub test` config as
        // `unittest` config in the DSL (`configToDubInfo`) (for
        // `dubTest!()`, `dubBuild!(Configuration("unittest"))` etc.)
        if(configs.haveTestConfig && configs.test != "unittest" && configs.test in ret)
            ret["unittest"] = ret[configs.test];

        return ret;
    }

    private static auto getGeneratorSettings(in Options options) {
        import dub.compilers.compiler: getCompiler;
        import dub.generators.generator: GeneratorSettings;
        import dub.internal.vibecompat.inet.path: NativePath;
        import std.path: baseName, stripExtension;

        GeneratorSettings ret;

        ret.cache = NativePath(options.workingDir) ~ "__dub_cache__";
        ret.compiler = () @trusted { return getCompiler(options.compilerBinName); }();
        ret.platform = () @trusted {
            return ret.compiler.determinePlatform(ret.buildSettings,
                options.dCompiler, options.dubArchOverride);
        }();
        ret.buildType = options.dubBuildType;

        return ret;
    }

    DubConfigurations dubConfigurations(O)(ref O output) {
        import reggae.io: log;

        output.log("Getting dub configurations");
        auto ret = getConfigs;
        output.log("Number of dub configurations: ", ret.configurations.length);

        // this happens e.g. the targetType is "none"
        if(ret.configurations.length == 0)
            return DubConfigurations([""], "", null);

        return ret;
    }

    private DubConfigurations getConfigs() {
        import std.algorithm: filter, map, canFind;
        import std.array: array;
        import std.conv: text;

        auto singleConfig = _options.dubConfig;
        const allConfigs = singleConfig == "";
        // add the special `dub test` configuration (which doesn't require an existing `unittest` config)
        const lookingForUnitTestsConfig = allConfigs || singleConfig == "unittest";
        const testConfig = lookingForUnitTestsConfig
            ? _dub.project.addTestRunnerConfiguration(_generatorSettings)
            : null; // skip when requesting a single non-unittest config

        // error out if the test config is explicitly requested but not available
        if(_options.dubConfig == "unittest" && testConfig == "") {
            throw new Exception("No dub test configuration available (target type 'none'?)");
        }

        const haveSpecialTestConfig = testConfig.length && testConfig != "unittest";
        const defaultConfig = _dub.project.getDefaultConfiguration(_generatorSettings.platform);

        // A violation of the Law of Demeter caused by a dub bug.
        // Otherwise _dub.project.configurations would do, but it fails for one
        // projet and no reduced test case was found.
        auto allConfigurationsAsStrings =
            _dub.project
            .rootPackage
            .recipe
            .configurations
            .filter!(c => c.matchesPlatform(_generatorSettings.platform))
            .map!(c => c.name)
            .array
            ;

        if (!allConfigs) { // i.e. one single config specified by the user
            // translate `unittest` to the actual test configuration
            const requestedConfig = haveSpecialTestConfig ? testConfig : singleConfig;


            const canFindConfig = allConfigurationsAsStrings.canFind(requestedConfig);
            if (!canFindConfig && requestedConfig != "default")
                throw new Exception(
                    text("Unknown dub configuration `", requestedConfig, "` - known configurations:\n    ",
                         allConfigurationsAsStrings)
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

        auto configurations = allConfigurationsAsStrings
            // exclude unittest config if there's a derived special one
            .filter!(n => !haveSpecialTestConfig || n != "unittest")
            .array;

        return DubConfigurations(configurations, defaultConfig, testConfig);
    }

    private imported!"reggae.dub.info".DubInfo configToDubInfo
        (O)
        (ref O output,
         in string config,
         in bool isTestConfig)
    {
        import reggae.io: log;
        import std.conv: text;

        output.log("Querying dub configuration '", config, "' of ", _options.projectPath);

        auto dubInfo = configToDubInfo(config);

        /**
         For the `dub test` config, add `-unittest` (only for the main package, hence [0]).
         [Similarly, `dub test` implies `--build=unittest`, with the unittest build type
         being the debug one + `-unittest`.]

         This enables (assuming no custom reggaefile.d):
         * `reggae && ninja default ut`
           => default `debug` build type for default config, extra `-unittest` for test config
         * `reggae --dub-config=unittest && ninja`
           => no need for extra `--dub-build-type=unittest`
         */
        if(isTestConfig) {
            if(dubInfo.packages.length == 0)
                throw new Exception(
                    text("No main package in `", config, "` configuration"));
            dubInfo.packages[0].dflags ~= "-unittest";
        }

        try
            callPreBuildCommands(output, options.projectPath, dubInfo);
        catch(Exception e) {
            output.log("Error calling prebuild commands: ", e.msg);
            throw e;
        }

        return dubInfo;
    }

    private DubInfo configToDubInfo(in string config = "") @trusted /*dub*/ {
        auto generator = new InfoGenerator(_dub.project, _extraDFlags);
        auto settings = _generatorSettings;
        settings.config = config;
        generator.generate(settings);
        return DubInfo(generator.dubPackages, _options.dup);
    }
}


// only exists because the dub API is "challenging" Only use this
// function if a "full dub" is needed, since it will cause the package
// recipe to be parsed, as well as all recipes for all packages
// already downloaded. See other usages of the `Dub` class in this
// module that don't do that on purpose for speed reasons.
auto fullDub(in string projectPath) @trusted {
    import dub.dub: DubClass = Dub;
    import dub.packagemanager: PackageManager;
    import dub.internal.vibecompat.inet.path: NativePath;

    // Cache the PackageManager.
    // A reggaefile.d with lots of dub{Package,Dependant} targets benefits from
    // this, also depending on the size of the dub packages cache.
    static class DubWithCachedPackageManager : DubClass {
        this(string rootPath) {
            super(rootPath);
        }

        override PackageManager makePackageManager() const {
            static PackageManager cachedPM = null;
            if (!cachedPM) {
                // The PackageManager wants a path to a local directory, for an
                // implicit `<local>/.dub/packages` repo. The base
                // implementation uses the dub root project directory; use the
                // reggae project directory as our local root.
                import reggae.config: options;
                auto localRoot = NativePath(options.projectPath);
                cachedPM = new PackageManager(localRoot, m_dirs.userPackages, m_dirs.systemSettings, false);
            }
            return cachedPM;
        }
    }

    auto dub = new DubWithCachedPackageManager(projectPath);
    dub.packageManager.getOrLoadPackage(NativePath(projectPath));
    dub.loadPackage();
    dub.project.validate();

    return dub;
}

private auto recipe(in string projectPath) @safe {
    import dub.recipe.packagerecipe: PackageRecipe;
    import dub.recipe.json: parseJson;
    import dub.recipe.sdl: parseSDL;
    static import dub.internal.vibecompat.data.json;
    import std.file: readText, exists;

    PackageRecipe recipe;

    string inProjectPath(in string path) {
        import reggae.path: buildPath;
        return buildPath(projectPath, path);
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
        throw new Exception("Could not find dub.sdl or dub.json in " ~ projectPath);
}

class InfoGenerator: imported!"dub.generators.generator".ProjectGenerator {
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

// FIXME - this should be called by ninja/make/etc., not here
private void callPreBuildCommands(O)(ref O output,
                                     in string workDir,
                                     in imported!"reggae.dub.info".DubInfo dubInfo)
    @safe
{
    import reggae.io: log;
    import std.process: executeShell, Config;
    import std.string: replace;
    import std.exception: enforce;
    import std.conv: text;

    const string[string] env = null;
    Config config = Config.none;
    size_t maxOutput = size_t.max;

    if(dubInfo.packages.length == 0) return;

    foreach(const package_; dubInfo.packages) {
        foreach(const dubCommandString; package_.preBuildCommands) {
            auto cmd = dubCommandString.replace("$project", workDir);
            output.log("Executing pre-build command `", cmd, "`");
            const ret = executeShell(cmd, env, config, maxOutput, workDir);
            enforce(ret.status == 0, text("Error calling ", cmd, ":\n", ret.output));
        }
    }
}
