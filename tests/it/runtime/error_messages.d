module tests.it.runtime.error_messages;

import reggae.reggae;
import unit_threaded;
import tests.it.runtime;

@("Non-existent directory error message") unittest {
    Runtime().runReggae(["-b", "binary"], "/non/existent").shouldThrowWithMessage(
        "Could not find /non/existent/reggaefile.d"
    );
}

@("Non-existent build description error message") unittest {
    immutable runtime = Runtime();

    runtime.writeFile("foo.txt");
    runtime.runReggae("-b", "binary").shouldThrowWithMessage(
        "Could not find " ~ buildPath(runtime.testPath, "reggaefile.d")
    );
}


@("Too many languages") unittest {
    immutable runtime = Runtime();

    runtime.writeFile("reggaefile.d");
    runtime.writeFile("reggaefile.py");

    runtime.runReggae("-b", "binary").shouldThrowWithMessage(
        "Reggae builds may only use one language. Found: D, Python"
    );

    runtime.writeFile("reggaefile.rb");
    runtime.runReggae("-b", "binary").shouldThrowWithMessage(
        "Reggae builds may only use one language. Found: D, Python, Ruby"
    );

    runtime.writeFile("reggaefile.js");
    runtime.runReggae("-b", "binary").shouldThrowWithMessage(
        "Reggae builds may only use one language. Found: D, Python, Ruby, JavaScript"
    );

    runtime.writeFile("reggaefile.lua");
    runtime.runReggae("-b", "binary").shouldThrowWithMessage(
        "Reggae builds may only use one language. Found: D, Python, Ruby, JavaScript, Lua"
    );
}
