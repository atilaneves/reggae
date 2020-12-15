module tests.it.buildgen.outputs_in_project_path;

import tests.it;
import std.file;

@("lorem")
@AutoTags
@Values("ninja", "make", "binary")
unittest {
    enum module_ = "outputs_in_project_path.reggaefile";
    auto options = _testProjectOptions!module_;

    doTestBuildFor!module_(options);
    inPath(options, "generated/release/64/linux/copy.txt").exists.shouldBeTrue;
}
