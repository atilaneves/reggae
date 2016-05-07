module tests.it.runtime.error_messages;

import reggae.reggae;
import unit_threaded;
import tests.it.runtime;

@("Non-existent directory error message") unittest {
    Reggae().run(["-b", "binary"], "/non/existent").shouldThrowWithMessage(
        "Could not find /non/existent/reggaefile.d"
    );
}

@("Non-existent build description error message") unittest {
    immutable reggae = Reggae();

    reggae.writeFile("foo.txt");
    reggae.run("-b", "binary").shouldThrowWithMessage(
        "Could not find " ~ buildPath(reggae.testPath, "reggaefile.d")
    );
}


@("Too many languages") unittest {
    immutable reggae = Reggae();

    reggae.writeFile("reggaefile.d");
    reggae.writeFile("reggaefile.py");

    reggae.run("-b", "binary").shouldThrowWithMessage(
        "Reggae builds may only use one language. Found: D, Python"
    );

    reggae.writeFile("reggaefile.rb");
    reggae.run("-b", "binary").shouldThrowWithMessage(
        "Reggae builds may only use one language. Found: D, Python, Ruby"
    );

    reggae.writeFile("reggaefile.js");
    reggae.run("-b", "binary").shouldThrowWithMessage(
        "Reggae builds may only use one language. Found: D, Python, Ruby, JavaScript"
    );

    reggae.writeFile("reggaefile.lua");
    reggae.run("-b", "binary").shouldThrowWithMessage(
        "Reggae builds may only use one language. Found: D, Python, Ruby, JavaScript, Lua"
    );
}
