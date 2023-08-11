module tests.it.runtime.error_messages;

import reggae.path: buildPath;
import reggae.reggae;
import unit_threaded;
import tests.it.runtime;

@("Non-existent directory error message") unittest {
    version(Windows)
        enum projectPath = "C:/non/existent";
    else
        enum projectPath = "/non/existent";

    ReggaeSandbox().runReggae(["-b", "ninja"], projectPath).shouldThrowWithMessage(
        "Could not find " ~ buildPath(projectPath, "reggaefile.d")
    );
}

@("Non-existent build description error message") unittest {
    import reggae.path: buildPath;

    with(immutable ReggaeSandbox()) {
        writeFile("foo.txt");
        runReggae("-b", "ninja").shouldThrowWithMessage(
            "Could not find " ~ buildPath(testPath, "reggaefile.d"));
    }
}


@("Too many languages") unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("reggaefile.d");
        writeFile("reggaefile.py");

        runReggae("-b", "ninja").shouldThrowWithMessage(
            "Reggae builds may only use one language. Found: D, Python"
            );

        writeFile("reggaefile.rb");
        runReggae("-b", "ninja").shouldThrowWithMessage(
            "Reggae builds may only use one language. Found: D, Python, Ruby"
            );

        writeFile("reggaefile.js");
        runReggae("-b", "ninja").shouldThrowWithMessage(
            "Reggae builds may only use one language. Found: D, Python, Ruby, JavaScript"
            );

        writeFile("reggaefile.lua");
        runReggae("-b", "ninja").shouldThrowWithMessage(
            "Reggae builds may only use one language. Found: D, Python, Ruby, JavaScript, Lua"
            );
    }
}
