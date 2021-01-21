import unit_threaded;

mixin runTestsMain!(
    "tests.ut.by_package",
    "tests.ut.cpprules",
    "tests.ut.options",
    "tests.ut.serialisation",
    "tests.ut.realistic_build",
    "tests.ut.drules",
    "tests.ut.backend.binary",
    "tests.ut.backend.ninja",
    "tests.ut.backend.make",
    "tests.ut.simple_foo_reggaefile",
    "tests.ut.ninja",
    "tests.ut.simple_bar_reggaefile",
    "tests.ut.default_options",
    "tests.ut.json_build.rules",
    "tests.ut.json_build.simple",
    "tests.ut.tup",
    "tests.ut.high_rules",
    "tests.ut.code_command",
    "tests.ut.build",
    "tests.ut.dcompile",
    "tests.ut.dependencies",
    "tests.ut.default_rules",
    "tests.ut.rules.link",
    "tests.ut.rules.common",
    "tests.ut.reflect",
    "tests.ut.range",
    "tests.ut.ctaa",
    "tests.ut.types",
    "tests.it.backend.binary",
    "tests.it.buildgen.arbitrary",
    "tests.it.buildgen.reggaefile_errors",
    "tests.it.buildgen.phony",
    "tests.it.buildgen.multiple_outputs",
    "tests.it.buildgen.export_",
    "tests.it.buildgen.optional",
    "tests.it.buildgen.backend_errors",
    "tests.it.buildgen.automatic_dependency",
    "tests.it.buildgen.implicits",
    "tests.it.buildgen.code_command",
    "tests.it.buildgen",
    "tests.it.buildgen.outputs_in_project_path",
    "tests.it.buildgen.two_builds_reggaefile",
    "tests.it.buildgen.empty_reggaefile",
    "tests.it",
    "tests.it.rules.scriptlike",
    "tests.it.rules.json_build",
    "tests.it.rules.object_files",
    "tests.it.rules.static_lib",
    "tests.it.rules.unity_build",
    "tests.it.runtime.lua",
    "tests.it.runtime.javascript",
    "tests.it.runtime.user_vars",
    "tests.it.runtime.error_messages",
    "tests.it.runtime.regressions",
    "tests.it.runtime.ruby",
    "tests.it.runtime.python",
    "tests.it.runtime",
    "tests.it.runtime.dub",
    "tests.it.runtime.issues",
);
