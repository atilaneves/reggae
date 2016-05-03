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
    import std.stdio;
    import std.path;

    const testPath = newTestDir;
    {
        auto file = File(buildPath(testPath, "reggaefile.rb"), "w");
        file.writeln(`require 'reggae'`);
        file.writeln(`helloObj = object_files(src_dirs: ['src'])`);
        file.writeln(`app = link(exe_name: 'app', dependencies: helloObj)`);
        file.writeln(`bld = Build.new(app)`);
    }

    writeHelloWorldApp(testPath);

    testRun(["reggae", "-C", testPath, "-b", "ninja", testPath]);
    ninja.shouldExecuteOk(testPath);
    buildPath(testPath, "app").shouldExecuteOk(testPath).shouldEqual(
        ["Hello world!"]);
}
