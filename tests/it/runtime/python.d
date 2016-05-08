/**
  As a reggae user
  I want to be able to write build descriptions in Python
  So I don't have to compile the build description
 */

module tests.it.runtime.python;

import tests.it.runtime;

@("Build description in Python")
@Tags(["ninja", "json_build"])
unittest {
    with(Sandbox()) {
        writeFile("reggaefile.py",
                  [`from reggae import *`,
                   `b = Build(executable(name='app', src_dirs=['src']))`]);
        writeHelloWorldApp;

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk(testPath);
        shouldSucceed("app").shouldEqual(["Hello world!"]);
    }
}
