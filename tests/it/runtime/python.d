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
    immutable runtime = Runtime();
    runtime.writeFile("reggaefile.py",
                     [`from reggae import *`,
                      `b = Build(executable(name='app', src_dirs=['src']))`]);
    runtime.writeHelloWorldApp;

    runtime.runReggae("-b", "ninja");
    ninja.shouldExecuteOk(runtime.testPath);
    buildPath(runtime.testPath, "app").shouldExecuteOk(runtime.testPath).shouldEqual(
        ["Hello world!"]);
}
