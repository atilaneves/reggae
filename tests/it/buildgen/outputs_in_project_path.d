module tests.it.buildgen.outputs_in_project_path;

import tests.it;
import std.file;


static foreach (backend; ["ninja", "make", "binary"])
    @("lorem (" ~ backend ~ ")")
    @Tags(backend)
    unittest {
        enum module_ = "outputs_in_project_path.reggaefile";
        auto options = testProjectOptions!module_(backend);

        doTestBuildFor!module_(options);
        inPath(options, "generated/release/64/linux/copy.txt").exists.shouldBeTrue;
    }
