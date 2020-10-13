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
    import std.process: environment;
    import std.path: buildPath, isAbsolute;
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
    import std.process: environment;
    import std.path: buildPath;

    version(Windows)
        const path = buildPath(environment.get("ProgramData"), "dub/");
    else version(Posix)
        const path = "/var/lib/dub/";
    else
        static assert(false, "Unknown system");

    return SystemPackagesPath(path);
}

enum Compiler {
    dmd,
    ldc,
    gdc,
}


package from!"reggae.dub.interop.configurations".DubConfigurations dubConfigurations(
    in ProjectPath projectPath,
    in SystemPackagesPath systemPackagesPath,
    in UserPackagesPath userPackagesPath,
    in Compiler compiler,
    )
    @trusted  // dub...
{
    import reggae.dub.interop.configurations: DubConfigurations;
    import reggae.dub.interop.dublib: project, InfoGenerator;

    auto proj = project(projectPath, systemPackagesPath, userPackagesPath);
    auto generator = new InfoGenerator(proj);

    return DubConfigurations(generator.configurations, generator.defaultConfiguration);
}


package from!"reggae.dub.info".DubInfo configToDubInfo
    (O)
    (auto ref O output, in from!"reggae.options".Options options, in string config)
    @trusted  // dub
{
    import reggae.dub.info: DubInfo;
    import reggae.dub.interop.dublib: project, generatorSettings, InfoGenerator,
        systemPackagesPath, userPackagesPath, ProjectPath, Compiler;
    import std.conv: to;

    auto proj = project(
        ProjectPath(options.projectPath),
        systemPackagesPath,
        userPackagesPath,
    );

    auto generator = new InfoGenerator(proj);
    generator.generate(generatorSettings(options.dCompiler.to!Compiler, config));

    return DubInfo(generator.dubPackages);
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

    this(in SystemPackagesPath systemPackagesPath, in UserPackagesPath userPackagesPath) @safe {
        _packageManager = packageManager(systemPackagesPath, userPackagesPath);
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
        import std.path: buildPath;

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

auto generatorSettings(in Compiler compiler = Compiler.dmd, in string config = "") @safe {
    import dub.compilers.compiler: getCompiler;
    import dub.generators.generator: GeneratorSettings;
    import dub.platform: determineBuildPlatform;
    import std.conv: text;

    GeneratorSettings ret;

    ret.buildType = "debug";  // FIXME
    const compilerName = compiler.text;
    ret.compiler = () @trusted { return getCompiler(compilerName); }();
    ret.platform.compilerBinary = compilerName;  // FIXME? (absolute path?)
    ret.config = config;
    ret.platform = () @trusted { return determineBuildPlatform; }();

    return ret;
}


auto project(in ProjectPath projectPath,
             in SystemPackagesPath systemPackagesPath,
             in UserPackagesPath userPackagesPath)
    @trusted
{
    import dub.project: Project;
    auto pkg = dubPackage(projectPath);
    return new Project(packageManager(systemPackagesPath, userPackagesPath), pkg);
}


private auto dubPackage(in ProjectPath projectPath) @trusted {
    import dub.internal.vibecompat.inet.path: NativePath;
    import dub.package_: Package;

    const nativeProjectPath = NativePath(projectPath.value);
    return new Package(recipe(projectPath), nativeProjectPath);
}


private auto recipe(in ProjectPath projectPath) @safe {
    import dub.recipe.packagerecipe: PackageRecipe;
    import dub.recipe.json: parseJson;
    import dub.recipe.sdl: parseSDL;
    static import dub.internal.vibecompat.data.json;
    import std.file: readText, exists;
    import std.path: buildPath;

    PackageRecipe recipe;

    string inProjectPath(in string path) {
        return buildPath(projectPath.value, path);
    }

    if(inProjectPath("dub.sdl").exists) {
        const text = readText(inProjectPath("dub.sdl"));
        () @trusted { parseSDL(recipe, text, "parent", "dub.sdl"); }();
        return recipe;
    } else if(inProjectPath("dub.json").exists) {
        auto text = readText(inProjectPath("dub.json"));
        auto json = () @trusted { return dub.internal.vibecompat.data.json.parseJson(text); }();
        () @trusted { parseJson(recipe, json, "parent"); }();
        return recipe;
    } else
        throw new Exception("Could not find dub.sdl or dub.json in " ~ projectPath.value);
}


auto packageManager(in SystemPackagesPath systemPackagesPath,
                    in UserPackagesPath userPackagesPath)
    @trusted
{
    import dub.internal.vibecompat.inet.path: NativePath;
    import dub.packagemanager: PackageManager;

    const userPath = NativePath(userPackagesPath.value);
    const systemPath = NativePath(systemPackagesPath.value);
    const refreshPackages = false;

    return new PackageManager(userPath, systemPath, refreshPackages);
}


class InfoGenerator: ProjectGenerator {
    import reggae.dub.info: DubPackage;
    import dub.project: Project;
    import dub.generators.generator: GeneratorSettings;

    DubPackage[] dubPackages;

    this(Project project) {
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

        bool[string] visited;

        void visitTargetRec(string targetName) {
            if (targetName in visited) return;
            visited[targetName] = true;

            const targetInfo = targets[targetName];

            auto newBuildSettings = targetInfo.buildSettings.dup;
            settings.compiler.prepareBuildSettings(newBuildSettings,
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

            dubPackages ~= pkg;

            foreach(dep; targetInfo.dependencies) visitTargetRec(dep);
        }

        visitTargetRec(m_project.rootPackage.name);
    }

    string[] configurations() @trusted const {
        return m_project.configurations;
    }

    string defaultConfiguration() @trusted const {
        auto settings = generatorSettings();
        return m_project.getDefaultConfiguration(settings.platform);
    }
}
