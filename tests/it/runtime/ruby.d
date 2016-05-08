/**
  As a reggae user
  I want to be able to write build descriptions in Ruby
  So I don't have to compile the build description
 */

module tests.it.runtime.ruby;

import tests.it.runtime;

@("Build description in ruby")
@Tags(["ninja", "json_build"])
unittest {

    with(Runtime()) {
        writeFile("reggaefile.rb",
            [
            `require 'reggae'`,
            `helloObj = object_files(src_dirs: ['src'])`,
            `app = link(exe_name: 'app', dependencies: helloObj)`,
            `bld = Build.new(app)`,
        ]);

        writeHelloWorldApp;

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk(testPath);
        buildPath(testPath, "app").shouldExecuteOk(testPath).shouldEqual(
        ["Hello world!"]);
    }
}
