module tests.it.runtime.error_messages;

import reggae.reggae;
import unit_threaded;
import tests.it.runtime;

@("Non-existent directory error message") unittest {
    testRun(["reggae", "-b", "binary", "/non/existent"]).shouldThrowWithMessage(
        "Could not find /non/existent/reggaefile.d");
}

@("Non-existent build description error message") unittest {
    import std.path;
    import std.stdio;

    auto testPath = newTestDir;
    {
        File(buildPath(testPath, "foo.txt"), "w").writeln;
    }
    testRun(["reggae", "-b", "binary", testPath]).shouldThrowWithMessage(
        "Could not find " ~ buildPath(testPath, "reggaefile.d")
        );
}


@("Too many languages") unittest {
    import std.path;
    import std.stdio;

    auto testPath = newTestDir;

    void writeFile(in string name) {
        File(buildPath(testPath, name), "w").writeln;
    }

    auto args = ["reggae", "-b", "binary", testPath];
    writeFile("reggaefile.d");
    writeFile("reggaefile.py");

    testRun(args).shouldThrowWithMessage(
        "Reggae builds may only use one language. Found: D, Python"
    );

    writeFile("reggaefile.rb");
    testRun(args).shouldThrowWithMessage(
        "Reggae builds may only use one language. Found: D, Python, Ruby"
    );

    writeFile("reggaefile.js");
    testRun(args).shouldThrowWithMessage(
        "Reggae builds may only use one language. Found: D, Python, Ruby, JavaScript"
    );

    writeFile("reggaefile.lua");
    testRun(args).shouldThrowWithMessage(
        "Reggae builds may only use one language. Found: D, Python, Ruby, JavaScript, Lua"
        );

}
