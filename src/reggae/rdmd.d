/*
 *  Copyright (C) 2008 by Andrei Alexandrescu
 *  Written by Andrei Alexandrescu, www.erdani.org
 *  Based on an idea by Georg Wrede
 *  Featuring improvements suggested by Christopher Wright
 *  Windows port using bug fixes and suggestions by Adam Ruppe
 *
 *
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */

// Written in the D programming language.
module reggae.rdmd;

import std.algorithm, std.array, core.stdc.stdlib, std.datetime,
std.digest.md, std.exception, std.file, std.getopt,
std.parallelism, std.path, std.process, std.range, std.regex,
std.stdio, std.string, std.typetuple;

version (Posix)
{
    enum objExt = ".o";
    enum binExt = "";
    enum libExt = ".a";
    enum altDirSeparator = "";
}
else version (Windows)
     {
         enum objExt = ".obj";
         enum binExt = ".exe";
         enum libExt = ".lib";
         enum altDirSeparator = "/";
     }
else
{
    static assert(0, "Unsupported operating system.");
}

private bool chatty, buildOnly, dryRun, force, preserveOutputPaths;
private string exe;
private string[] exclusions = ["std", "etc", "core"]; // packages that are to be excluded
private string[] extraFiles = [];

version (DigitalMars)
private enum defaultCompiler = "dmd";
else version (GNU)
         private enum defaultCompiler = "gdmd";
else version (LDC)
         private enum defaultCompiler = "ldmd2";
else
    static assert(false, "Unknown compiler");

private string compiler = defaultCompiler;


size_t indexOfProgram(string[] args)
{
    foreach(i, arg; args[1 .. $])
    {
        if (!arg.startsWith('-', '@') &&
            !arg.endsWith(".obj", ".o", ".lib", ".a", ".def", ".map", ".res"))
        {
            return i + 1;
        }
    }

    return args.length;
}

void writeDeps(string exe, string root, in string[string] myDeps, File fo)
{
    fo.writeln(exe, ": \\");
    fo.write(" ", root);
    foreach (mod, _; myDeps)
    {
        fo.writeln(" \\");
        fo.write(" ", mod);
    }
    fo.writeln();
    fo.writeln();
    fo.writeln(root, ":");
    foreach (mod, _; myDeps)
    {
        fo.writeln('\n', mod, ":");
    }
}

bool inALibrary(string source, string object)
{
    if (object.endsWith(".di")
        || source == "object" || source == "gcstats")
        return true;

    foreach(string exclusion; exclusions)
        if (source.startsWith(exclusion~'.'))
            return true;

    // https://issues.dlang.org/show_bug.cgi?id=13178
    // print a warning about `tango` removal for one release cycle
    static bool seenTango;
    if (!seenTango && source.startsWith("tango."))
    {
        seenTango = true;
        stderr.writeln(
            "Warning: 'tango' package is no longer automatically excluded from compilation.\n" ~
            "Warning:  modify your build script to mention --exclude=tango to keep the old behaviour"
            );
    }

    return false;

    // another crude heuristic: if a module's path is absolute, it's
    // considered to be compiled in a separate library. Otherwise,
    // it's a source module.
    //return isabs(mod);
}

private @property string myOwnTmpDir()
{
    auto tmpRoot = tempDir();
    version (Posix)
    {
        import core.sys.posix.unistd;
        tmpRoot = buildPath(tmpRoot, ".rdmd-%d".format(getuid()));
    }
    else
        tmpRoot = tmpRoot.replace("/", dirSeparator).buildPath(".rdmd");

    yap("mkdirRecurse ", tmpRoot);
    if (!dryRun)
        mkdirRecurse(tmpRoot);
    return tmpRoot;
}

private string getWorkPath(in string root, in string[] compilerFlags)
{
    static string workPath;
    if (workPath)
        return workPath;

    enum string[] irrelevantSwitches = [
        "--help", "-ignore", "-quiet", "-v" ];

    MD5 context;
    context.start();
    context.put(root.absolutePath().representation);
    foreach (flag; compilerFlags)
    {
        if (irrelevantSwitches.canFind(flag)) continue;
        context.put(flag.representation);
    }
    auto digest = context.finish();
    string hash = toHexString(digest);

    const tmpRoot = myOwnTmpDir;
    workPath = buildPath(tmpRoot,
                         "rdmd-" ~ baseName(root) ~ '-' ~ hash);

    yap("mkdirRecurse ", workPath);
    if (!dryRun)
        mkdirRecurse(workPath);

    return workPath;
}

private File lockFile;

private void lockWorkPath(string workPath)
{
    string lockFileName = buildPath(workPath, "rdmd.lock");
    if (!dryRun) lockFile.open(lockFileName, "w");
    yap("lock ", lockFile.name);
    if (!dryRun) lockFile.lock();
}

private void unlockWorkPath()
{
    yap("unlock ", lockFile.name);
    if (!dryRun)
    {
        lockFile.unlock();
        lockFile.close();
    }
}

// Rebuild the executable fullExe starting from modules in myDeps
// passing the compiler flags compilerFlags. Generates one large
// object file.

private int rebuild(string root, string fullExe,
                    string workDir, string objDir, in string[string] myDeps,
                    string[] compilerFlags, bool addStubMain)
{
    version (Windows)
        fullExe = fullExe.defaultExtension(".exe");

    // Delete the old executable before we start building.
    yap("stat ", fullExe);
    if (!dryRun && exists(fullExe))
    {
        yap("rm ", fullExe);
        try
            remove(fullExe);
        catch (FileException e)
        {
            // This can occur on Windows if the executable is locked.
            // Although we can't delete the file, we can still rename it.
            auto oldExe = "%s.%s-%s.old".format(fullExe,
                                                Clock.currTime.stdTime, thisProcessID);
            yap("mv ", fullExe, " ", oldExe);
            rename(fullExe, oldExe);
        }
    }

    auto fullExeTemp = fullExe ~ ".tmp";

    string[] buildTodo()
    {
        auto todo = compilerFlags
            ~ [ "-of"~fullExeTemp ]
            ~ [ "-od"~objDir ]
            ~ [ "-I"~dirName(root) ]
            ~ [ root ];
        foreach (k, objectFile; myDeps) {
            if(objectFile !is null)
                todo ~= [ k ];
        }
        // Need to add void main(){}?
        if (addStubMain)
        {
            auto stubMain = buildPath(myOwnTmpDir, "stubmain.d");
            std.file.write(stubMain, "void main(){}");
            todo ~= [ stubMain ];
        }
        return todo;
    }
    auto todo = buildTodo();

    // Different shells and OS functions have different limits,
    // but 1024 seems to be the smallest maximum outside of MS-DOS.
    enum maxLength = 1024;
    auto commandLength = escapeShellCommand(todo).length;
    if (commandLength + compiler.length >= maxLength)
    {
        auto rspName = buildPath(workDir, "rdmd.rsp");

        // DMD uses Windows-style command-line parsing in response files
        // regardless of the operating system it's running on.
        std.file.write(rspName, array(map!escapeWindowsArgument(todo)).join(" "));

        todo = [ "@"~rspName ];
    }

    immutable result = run([ compiler ] ~ todo);
    if (result)
    {
        // build failed
        if (exists(fullExeTemp))
            remove(fullExeTemp);
        return result;
    }
    // clean up the dir containing the object file, just not in dry
    // run mode because we haven't created any!
    if (!dryRun)
    {
        yap("stat ", objDir);
        if (objDir.exists && objDir.startsWith(workDir))
        {
            yap("rmdirRecurse ", objDir);
            // We swallow the exception because of a potential race: two
            // concurrently-running scripts may attempt to remove this
            // directory. One will fail.
            collectException(rmdirRecurse(objDir));
        }
        yap("mv ", fullExeTemp, " ", fullExe);
        rename(fullExeTemp, fullExe);
    }
    return 0;
}

// Run a program optionally writing the command line first
// If "replace" is true and the OS supports it, replace the current process.

private int run(string[] args, string output = null, bool replace = false)
{
    import std.conv;
    yap(replace ? "exec " : "spawn ", args.text);
    if (dryRun) return 0;

    if (replace && !output)
    {
        version (Windows)
        { /* Windows doesn't have exec, fall back to spawnProcess+wait */ }
        else
        {
            import std.c.process;
            auto argv = args.map!toStringz.chain(null.only).array;
            return execv(argv[0], argv.ptr);
        }
    }

    File outputFile;
    if (output)
        outputFile = File(output, "wb");
    else
        outputFile = stdout;
    auto process = spawnProcess(args, stdin, outputFile);
    return process.wait();
}

private int exec(string[] args)
{
    return run(args, null, true);
}

// Given module rootModule, returns a mapping of all dependees .d
// source filenames to their corresponding .o files sitting in
// directory workDir. The mapping is obtained by running dmd -v against
// rootModule.

public string[string] getDependencies(string rootModule, string workDir,
                                      string objDir, string[] compilerFlags)
{
    yap("*** rootModule: ", rootModule);
    yap("*** workDir: ", workDir);
    immutable depsFilename = buildPath(workDir, "rdmd.deps");

    string[string] readDepsFile()
    {
        string d2obj(string dfile)
        {
            return buildPath(objDir, dfile.baseName.chomp(".d") ~ objExt);
        }
        string findLib(string libName)
        {
            // This can't be 100% precise without knowing exactly where the linker
            // will look for libraries (which requires, but is not limited to,
            // parsing the linker's command line (as specified in dmd.conf/sc.ini).
            // Go for best-effort instead.
            string[] dirs = ["."];
            foreach (envVar; ["LIB", "LIBRARY_PATH", "LD_LIBRARY_PATH"])
                dirs ~= environment.get(envVar, "").split(pathSeparator);
            version (Windows)
                string[] names = [libName ~ ".lib"];
            else
            {
                string[] names = ["lib" ~ libName ~ ".a", "lib" ~ libName ~ ".so"];
                dirs ~= ["/lib", "/usr/lib"];
            }
            foreach (dir; dirs)
                foreach (name; names)
                {
                    auto path = buildPath(dir, name);
                    if (path.exists)
                        return absolutePath(path);
                }
            return null;
        }
        yap("read ", depsFilename);
        auto depsReader = File(depsFilename);
        scope(exit) collectException(depsReader.close()); // don't care for errors

        // Fetch all dependencies and append them to myDeps
        auto pattern = regex(r"^(import|file|binary|config|library)\s+([^\(]+)\(?([^\)]*)\)?\s*$");
        string[string] result;
        foreach (string line; lines(depsReader))
        {
            auto regexMatch = match(line, pattern);
            if (regexMatch.empty) continue;
            auto captures = regexMatch.captures;
            switch(captures[1])
            {
            case "import":
                immutable moduleName = captures[2].strip(), moduleSrc = captures[3].strip();
                if (inALibrary(moduleName, moduleSrc)) continue;
                immutable moduleObj = d2obj(moduleSrc);
                result[moduleSrc] = moduleObj;
                break;

            case "file":
                result[captures[3].strip()] = null;
                break;

            case "binary":
                result[which(captures[2].strip())] = null;
                break;

            case "config":
                auto confFile = captures[2].strip;
                // The config file is special: if missing, that's fine too. So
                // add it as a dependency only if it actually exists.
                yap("stat ", confFile);
                if (confFile.exists)
                {
                    result[confFile] = null;
                }
                break;

            case "library":
                immutable libName = captures[2].strip();
                immutable libPath = findLib(libName);
                if (libPath)
                {
                    yap("library ", libName, " ", libPath);
                    result[libPath] = null;
                }
                break;

            default: assert(0);
            }
        }
        // All dependencies specified through --extra-file
        foreach (immutable moduleSrc; extraFiles)
            result[moduleSrc] = d2obj(moduleSrc);
        return result;
    }

    // Check if the old dependency file is fine
    if (!force)
    {
        yap("stat ", depsFilename);
        auto depsT = depsFilename.timeLastModified(SysTime.min);
        if (depsT > SysTime.min)
        {
            // See if the deps file is still in good shape
            auto deps = readDepsFile();
            auto allDeps = chain(rootModule.only, deps.byKey).array;
            bool mustRebuildDeps = allDeps.anyNewerThan(depsT);
            if (!mustRebuildDeps)
            {
                // Cool, we're in good shape
                return deps;
            }
            // Fall through to rebuilding the deps file
        }
    }

    immutable rootDir = dirName(rootModule);

    // Collect dependencies
    auto depsGetter =
        // "cd "~shellQuote(rootDir)~" && "
        [ compiler ] ~ compilerFlags ~
        ["-v", "-o-", rootModule, "-I"~rootDir];

    scope(failure)
    {
        // Delete the deps file on failure, we don't want to be fooled
        // by it next time we try
        collectException(std.file.remove(depsFilename));
    }

    immutable depsExitCode = run(depsGetter, depsFilename);
    if (depsExitCode)
    {
        stderr.writefln("Failed: %s", depsGetter);
        collectException(std.file.remove(depsFilename));
        exit(depsExitCode);
    }

    return dryRun ? null : readDepsFile();
}

// Is any file newer than the given file?
bool anyNewerThan(in string[] files, in string file)
{
    yap("stat ", file);
    return files.anyNewerThan(file.timeLastModified);
}

// Is any file newer than the given file?
bool anyNewerThan(in string[] files, SysTime t)
{
    // Experimental: running newerThan in separate threads, one per file
    if (false)
    {
        foreach (source; files)
        {
            if (source.newerThan(t))
            {
                return true;
            }
        }
        return false;
    }
    else
    {
        bool result;
        foreach (source; taskPool.parallel(files))
        {
            yap("stat ", source);
            if (!result && source.newerThan(t))
            {
                result = true;
            }
        }
        return result;
    }
}

/*
  If force is true, returns true. Otherwise, if source and target both
  exist, returns true iff source's timeLastModified is strictly greater
  than target's. Otherwise, returns true.
*/
private bool newerThan(string source, string target)
{
    if (force) return true;
    yap("stat ", target);
    return source.newerThan(target.timeLastModified(SysTime.min));
}

private bool newerThan(string source, SysTime target)
{
    if (force) return true;
    try
    {
        yap("stat ", source);
        return DirEntry(source).timeLastModified > target;
    }
    catch (Exception)
    {
        // File not there, consider it newer
        return true;
    }
}

private @property string helpString()
{
    return
        "rdmd build "~thisVersion~"
Usage: rdmd [RDMD AND DMD OPTIONS]... program [PROGRAM OPTIONS]...
Builds (with dependents) and runs a D program.
Example: rdmd -release myprog --myprogparm 5

Any option to be passed to the compiler must occur before the program name. In
addition to compiler options, rdmd recognizes the following options:
  --build-only       just build the executable, don't run it
  --chatty           write compiler commands to stdout before executing them
  --compiler=comp    use the specified compiler (e.g. gdmd) instead of %s
  --dry-run          do not compile, just show what commands would be run
                      (implies --chatty)
  --eval=code        evaluate code as in perl -e (multiple --eval allowed)
  --exclude=package  exclude a package from the build (multiple --exclude allowed)
  --extra-file=file  include an extra source or object in the compilation
                     (multiple --extra-file allowed)
  --force            force a rebuild even if apparently not necessary
  --help             this message
  --loop             assume \"foreach (line; stdin.byLine()) { ... }\" for eval
  --main             add a stub main program to the mix (e.g. for unittesting)
  --makedepend       print dependencies in makefile format and exit
                     (needs dmd's option `-of` to be present)
  --makedepfile=file print dependencies in makefile format to file and continue
                     (needs dmd's option `-of` to be present)
  --man              open web browser on manual page
  --shebang          rdmd is in a shebang line (put as first argument)
".format(defaultCompiler);
}

// For --eval
immutable string importWorld = "
module temporary;
import std.stdio, std.algorithm, std.array, std.ascii, std.base64,
    std.bigint, std.bitmanip,
    std.compiler, std.complex, std.concurrency, std.container, std.conv,
    std.cstream, std.csv,
    std.datetime, std.demangle, std.digest.md, std.encoding, std.exception,
    std.file,
    std.format, std.functional, std.getopt, std.json,
    std.math, std.mathspecial, std.mmfile,
    std.numeric, std.outbuffer, std.parallelism, std.path, std.process,
    std.random, std.range, std.regex, std.signals, std.socket,
    std.socketstream, std.stdint, std.stdio, std.stdiobase, std.stream,
    std.string, std.syserror, std.system, std.traits, std.typecons,
    std.typetuple, std.uni, std.uri, std.utf, std.variant, std.xml, std.zip,
    std.zlib;
";

string makeEvalFile(string todo)
{
    auto pathname = myOwnTmpDir;
    auto srcfile = buildPath(pathname,
            "eval." ~ todo.md5Of.toHexString ~ ".d");

    if (force || !exists(srcfile))
    {
        std.file.write(srcfile, todo);
    }

    // Clean pathname
    enum lifetimeInHours = 24;
    auto cutoff = Clock.currTime() - dur!"hours"(lifetimeInHours);
    yap("dirEntries ", pathname);
    foreach (DirEntry d; dirEntries(pathname, SpanMode.shallow))
    {
        yap("stat ", d.name);
        if (d.timeLastModified < cutoff)
        {
            collectException(std.file.remove(d.name));
            //break; // only one per call so we don't waste time
        }
    }

    return srcfile;
}

@property string thisVersion()
{
    enum d = __DATE__;
    enum month = d[0 .. 3],
        day = d[4] == ' ' ? "0"~d[5] : d[4 .. 6],
        year = d[7 .. $];
    enum monthNum
        = month == "Jan" ? "01"
        : month == "Feb" ? "02"
        : month == "Mar" ? "03"
        : month == "Apr" ? "04"
        : month == "May" ? "05"
        : month == "Jun" ? "06"
        : month == "Jul" ? "07"
        : month == "Aug" ? "08"
        : month == "Sep" ? "09"
        : month == "Oct" ? "10"
        : month == "Nov" ? "11"
        : month == "Dec" ? "12"
        : "";
    static assert(month != "", "Unknown month "~month);
    return year[0]~year[1 .. $]~monthNum~day;
}

string which(string path)
{
    yap("which ", path);
    if (path.canFind(dirSeparator) || altDirSeparator != "" && path.canFind(altDirSeparator)) return path;
    string[] extensions = [""];
    version(Windows) extensions ~= environment["PATHEXT"].split(pathSeparator);
    foreach (extension; extensions)
    {
        foreach (envPath; environment["PATH"].splitter(pathSeparator))
        {
            string absPath = buildPath(envPath, path ~ extension);
            yap("stat ", absPath);
            if (exists(absPath) && isFile(absPath))
                return absPath;
        }
    }
    throw new FileException(path, "File not found in PATH");
}

void yap(size_t line = __LINE__, T...)(auto ref T stuff)
{
    if (!chatty) return;
    debug stderr.writeln(line, ": ", stuff);
    else stderr.writeln(stuff);
}
