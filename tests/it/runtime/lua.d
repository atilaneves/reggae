/**
  As a reggae user
  I want to be able to write build descriptions in Lua
  So I don't have to compile the build description
 */

module tests.it.runtime.lua;

import tests.it.runtime;

@("Build description in Lua")
@Tags(["ninja", "json_build", "lua", "travis_oops"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("reggaefile.lua",
                  [
                      `local reggae = require('reggae')`,
                      `local helloObj = reggae.object_files({src_dirs = {'src'}})`,
                      `local app = reggae.link({exe_name = 'app', dependencies = helloObj})`,
                      `local bld = reggae.Build(app)`,
                      `return {bld = bld}`,
                   ]);
        writeHelloWorldApp;

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk(testPath);
        shouldSucceed("app").shouldEqual(["Hello world!"]);
    }
}
