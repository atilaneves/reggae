/**
  As a reggae user
  I want to be able to write build descriptions in Ruby
  So I don't have to compile the build description
 */

module tests.it.runtime.ruby;

import tests.it.runtime;

@("Build description in ruby")
@Tags(["ninja", "json_build", "ruby", "travis_oops"])
unittest {

    with(ReggaeSandbox()) {
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
        shouldSucceed("app").shouldEqual(["Hello world!"]);
    }
}

@("Erroneous description in ruby doesn't crash")
@Tags(["ninja", "json_build", "ruby", "travis_oops"])
unittest {
    with(ReggaeSandbox()) {
        writeFile("reggaefile.rb",
                  [
                      `require 'reggae'`,
                      // this is the difference: source dirs is not an array
                      `helloObj = object_files(src_dirs: 'src')`,
                      `app = link(exe_name: 'app', dependencies: helloObj)`,
                      `bld = Build.new(app)`,
                      ]);

        // it used to throw a raw JSONException
        runReggae("-b", "ninja").shouldThrowExactly!Exception;
    }
}
