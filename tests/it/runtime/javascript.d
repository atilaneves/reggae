/**
  As a reggae user
  I want to be able to write build descriptions in Javascript
  So I don't have to compile the build description
 */

module tests.it.runtime.javascript;

import tests.it.runtime;

@("Build description in Javascript")
@Tags(["ninja", "json_build", "javascript"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("reggaefile.js",
                  [
                      `var reggae = require('reggae-js')`,
                      `var helloObj = reggae.objectFiles({src_dirs: ['src']})`,
                      `var app = reggae.link({exe_name: 'app', dependencies: helloObj})`,
                      `exports.b = new reggae.Build(app)`,
                   ]);
        writeHelloWorldApp;

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk(testPath);
        shouldSucceed("app").shouldEqual(["Hello world!"]);
    }
}
