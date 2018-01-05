/**
  As a reggae user
  I want to be able to write build descriptions in Python
  So I don't have to compile the build description
 */

module tests.it.runtime.python;

import tests.it.runtime;

@("Build description")
@Tags(["ninja", "json_build", "python"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("reggaefile.py",
                  [`from reggae import *`,
                   `b = Build(executable(name='app', src_dirs=['src']))`]);
        writeHelloWorldApp;

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk(testPath);
        shouldSucceed("app").shouldEqual(["Hello world!"]);
    }
}

@("User variables")
@Tags(["ninja", "json_build", "python"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("reggaefile.py",
                  [`from reggae import *`,
                   `name = user_vars.get('name', 'app')`,
                   `b = Build(executable(name=name, src_dirs=['src']))`]);
        writeHelloWorldApp;

        runReggae("-b", "ninja", "-dname=foo");
        ninja.shouldExecuteOk(testPath);
        shouldSucceed("foo").shouldEqual(["Hello world!"]);
    }
}

@("default options")
@Tags(["ninja", "json_build", "python"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("reggaefile.py",
                  [`from reggae import *`,
                   `opts = DefaultOptions(dCompiler='nope')`,
                   `b = Build(executable(name='app', src_dirs=['src']))`]);
        writeHelloWorldApp;

        runReggae("-b", "ninja");
        // there's no binary named "nope" so the build fails
        ninja.shouldFailToExecute(testPath);
    }
}

@("Multiple runs will not crash")
@Tags(["ninja", "json_build", "python"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("reggaefile.py",
                [`from reggae import *`,
                 `b = Build(executable(name='app', src_dirs=['src']))`]);
        writeHelloWorldApp;

        runReggae("-b", "ninja", "-d", "foo=bar");
        runReggae("-b", "ninja", "-d", "foo=baz");
    }
}
