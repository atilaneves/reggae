module tests.ut.dub_json;


import unit_threaded;
import reggae;
import reggae.dub.json;
import std.string;

@("PACKAGE_DIR")
unittest {
    const jsonString = q{
        {
            "packages": [
                {
                    "name": "lepackage",
                    "path": "/dub/packages/lepackage",
                    "dflags": [],
                    "lflags": ["-L$PACKAGE_DIR"],
                    "importPaths": ["$PACKAGE_DIR/imports"],
                    "stringImportPaths": ["$PACKAGE_DIR/stringImports"],
                    "files": [
                        {"role": "source", "path": "$PACKAGE_DIR/foo.o"},
                        {"role": "source", "path": "src/file.d"}
                    ]
                },
                {
                    "name": "dep",
                    "path": "/dub/packages/dep",
                    "dflags": [],
                    "lflags": [],
                    "importPaths": [],
                    "stringImportPaths": [],
                    "files": [
                        {"role": "source", "path": "$PACKAGE_DIR/bar.o"},
                        {"role": "source", "path": "src/dep.d"}
                    ]
                }
            ]
        }
    };

    getDubInfo(jsonString).shouldEqual(
        DubInfo(
            [
                DubPackage(
                    "lepackage",
                    "/dub/packages/lepackage",
                    "", // mainSourceFile
                    "", // targetFileName
                    [], // dflags
                    ["-L/dub/packages/lepackage"],
                    ["/dub/packages/lepackage/imports"],
                    ["/dub/packages/lepackage/stringImports"],
                    ["/dub/packages/lepackage/foo.o", "src/file1.d"]
                ),
                DubPackage(
                    "dep",
                    "/dub/packages/dep",
                    "", // mainSourceFile
                    "", //targetFileName
                    [], // dflags
                    [], // lflags
                    [], // importPaths
                    [], // stringImportPaths
                    ["/dub/packages/lepackage/foo.o", "src/file1.d"]
                ),
            ]
    ));


}

immutable jsonString =
    `WARNING: A deprecated branch based version specification is used for the dependency unit-threaded. Please use numbered versions instead. Also note that you can still use the dub.selections.json file to override a certain dependency to use a branch instead.` ~
    `{` ~
    `  "packages": [` ~
    `    {` ~
    `      "targetType": "executable",` ~
    `      "path": "/path/to/pkg1",` ~
    `      "name": "pkg1",` ~
    `      "mainSourceFile": "src/boooo.d",` ~
    `      "targetFileName": "super_app",` ~
    `      "dflags": [],` ~
    `      "lflags": ["-L$LIB_DIR1", "-L$LIB_DIR2"],` ~
    `      "versions": ["v1", "v2"],` ~
    `      "dependencies": ["pkg_other"],` ~
    `      "importPaths": ["leimports"],` ~
    `      "stringImportPaths": [` ~
    `        "src/string_imports",` ~
    `        "src/moar_stringies"` ~
    `      ],` ~
    `      "active": true,` ~
    `      "preBuildCommands": ["dub run dtest"],` ~
    `      "files": [` ~
    `        {` ~
    `          "path": "src/foo.d",` ~
    `          "type": "source"` ~
    `        },` ~
    `        {` ~
    `          "path": "src/bar.d",` ~
    `          "type": "source"` ~
    `        },` ~
    `        {` ~
    `          "path": "src/boooo.d",` ~
    `          "type": "source"` ~
    `        }` ~
    `      ]` ~
    `    },` ~
    `    {` ~
    `      "path": "/weird/path/pkg_other",` ~
    `      "name": "pkg_other",` ~
    `      "importPaths": [` ~
    `        "my_imports",` ~
    `        "moar_imports"` ~
    `      ],` ~
    `      "dflags": [` ~
    `        "-g", "-debug"` ~
    `      ],` ~
    `      "lflags": [],` ~
    `      "libs": ["liblib", "otherlib"],` ~
    `      "versions": ["v3", "v4"],` ~
    `      "stringImportPaths": [],` ~
    `      "active": true,` ~
    `      "files": [` ~
    `        {` ~
    `          "path": "source/toto.d",` ~
    `          "type": "source"` ~
    `        },` ~
    `        {` ~
    `          "path": "source/africa.d",` ~
    `          "type": "source"` ~
    `        },` ~
    `        {` ~
    `          "path": "source/africa.d",` ~
    `          "type": "weirdo"` ~
    `        }` ~
    `      ]` ~
    `    }` ~
    `  ]` ~
    `}`;


void testJsonToDubDescribe() {
    auto info = getDubInfo(jsonString.dup);
    info.shouldEqual(
        DubInfo(
            [DubPackage("pkg1", "/path/to/pkg1", "src/boooo.d", "super_app",
                        [],
                        ["-L$LIB_DIR1", "-L$LIB_DIR2"],
                        ["leimports"],
                        ["src/string_imports", "src/moar_stringies"],
                        ["src/foo.d", "src/bar.d", "src/boooo.d"],
                        "executable", ["v1", "v2"], ["pkg_other"], [], true, ["dub run dtest"]),

             DubPackage("pkg_other", "/weird/path/pkg_other", "", "",
                        ["-g", "-debug"],
                        [],
                        ["my_imports", "moar_imports"],
                        [],
                        ["source/toto.d", "source/africa.d"],
                        "", ["v3", "v4"], [], ["liblib", "otherlib"], true)]));
}

@("DubInfo.toTargets with -unittest")
unittest {
    import reggae.config: setOptions, options;
    import reggae.options: getOptions;

    auto oldOptions = options;
    scope(exit) setOptions(oldOptions);
    setOptions(getOptions(["reggae", "--per_module", "/tmp/proj"]));

    auto info = getDubInfo(jsonString.dup);
    info.toTargets(Yes.main, "-unittest")[0].shouldEqual(
        Target("path/to/pkg1/src/foo.o",
               Command(CommandType.compile,
                       assocListT("includes", ["-I/path/to/pkg1/leimports",
                                               "-I/weird/path/pkg_other/my_imports",
                                               "-I/weird/path/pkg_other/moar_imports",
                                               "-I/tmp/proj"],
                                  "flags", ["-version=v1", "-version=v2", "-version=v3", "-version=v4", "-unittest"],
                                  "stringImports", ["-J/path/to/pkg1/src/string_imports",
                                                    "-J/path/to/pkg1/src/moar_stringies"],
                                  "DEPFILE", ["path/to/pkg1/src/foo.o.dep"])),
               Target("/path/to/pkg1/src/foo.d")),
    );

    info.toTargets(Yes.main, "-unittest")[3].shouldEqual(
        Target("weird/path/pkg_other/source/toto.o",
               Command(CommandType.compile,
                       assocListT("includes", ["-I/path/to/pkg1/leimports",
                                               "-I/weird/path/pkg_other/my_imports",
                                               "-I/weird/path/pkg_other/moar_imports",
                                               "-I/tmp/proj"],
                                  "flags", ["-g", "-debug", "-version=v1", "-version=v2", "-version=v3", "-version=v4"],
                                  "stringImports", cast(string[])[],
                                  "DEPFILE", ["weird/path/pkg_other/source/toto.o.dep"])),
               Target("/weird/path/pkg_other/source/toto.d")),
    );
}

void testDubInfoToTargets() {
    import reggae.config: setOptions, options;
    import reggae.options: getOptions;

    auto oldOptions = options;
    scope(exit) setOptions(oldOptions);

    setOptions(getOptions(["reggae", "--per_module", "/tmp/proj"]));

    auto info = getDubInfo(jsonString.dup);
    info.toTargets[0].shouldEqual(
        Target("path/to/pkg1/src/foo.o",
               Command(CommandType.compile,
                       assocListT("includes", ["-I/path/to/pkg1/leimports",
                                               "-I/weird/path/pkg_other/my_imports",
                                               "-I/weird/path/pkg_other/moar_imports",
                                               "-I/tmp/proj"],
                                  "flags", ["-version=v1", "-version=v2", "-version=v3", "-version=v4"],
                                  "stringImports", ["-J/path/to/pkg1/src/string_imports",
                                                    "-J/path/to/pkg1/src/moar_stringies"],
                                  "DEPFILE", ["path/to/pkg1/src/foo.o.dep"])),
               Target("/path/to/pkg1/src/foo.d")),
    );
    info.toTargets[2].shouldEqual(
        Target("path/to/pkg1/src/boooo.o",
               Command(CommandType.compile,
                       assocListT("includes", ["-I/path/to/pkg1/leimports",
                                               "-I/weird/path/pkg_other/my_imports",
                                               "-I/weird/path/pkg_other/moar_imports",
                                               "-I/tmp/proj"],
                                  "flags", ["-version=v1", "-version=v2", "-version=v3", "-version=v4"],
                                  "stringImports", ["-J/path/to/pkg1/src/string_imports",
                                                    "-J/path/to/pkg1/src/moar_stringies"],
                                  "DEPFILE", ["path/to/pkg1/src/boooo.o.dep"])),
               Target("/path/to/pkg1/src/boooo.d")),
        );

    info.toTargets(No.main)[2].shouldEqual(
        Target("weird/path/pkg_other/source/toto.o",
               Command(CommandType.compile,
                       assocListT("includes", ["-I/path/to/pkg1/leimports",
                                               "-I/weird/path/pkg_other/my_imports",
                                               "-I/weird/path/pkg_other/moar_imports",
                                               "-I/tmp/proj"],
                                  "flags", ["-g", "-debug", "-version=v1", "-version=v2", "-version=v3", "-version=v4"],
                                  "stringImports", cast(string[])[],
                                  "DEPFILE", ["weird/path/pkg_other/source/toto.o.dep"])),
               Target("/weird/path/pkg_other/source/toto.d")),

        );

}


@("dub describe with empty sources")
unittest {
    auto jsonString = `
Configuration 'library' of package test contains no source files. Please add {"targetType": "none"} to it's package description to avoid building it.
{
        "rootPackage": "test",
        "mainPackage": "test",
        "configuration": "library",
        "buildType": "debug",
        "compiler": "dmd",
        "architecture": [
                "x86_64"
        ],
        "platform": [
                "linux",
                "posix"
        ],
        "packages": [
                {
                        "path": "/tmp/test/",
                        "name": "test",
                        "version": "~master",
                        "description": "A minimal D application.",
                        "homepage": "",
                        "authors": [
                                "atila"
                        ],
                        "copyright": "Copyright © 2016, atila",
                        "license": "",
                        "dependencies": [],
                        "active": true,
                        "configuration": "library",
                        "targetType": "library",
                        "targetPath": "",
                        "targetName": "test",
                        "targetFileName": "libtest.a",
                        "workingDirectory": "",
                        "mainSourceFile": "",
                        "dflags": [],
                        "lflags": [],
                        "libs": [],
                        "copyFiles": [],
                        "versions": [],
                        "debugVersions": [],
                        "importPaths": [
                                "source/"
                        ],
                        "stringImportPaths": [],
                        "preGenerateCommands": [],
                        "postGenerateCommands": [],
                        "preBuildCommands": [],
                        "postBuildCommands": [],
                        "buildRequirements": [],
                        "options": [],
                        "files": []
                }
        ],
        "targets": []
}
        `;
    getDubInfo(jsonString);
}


immutable travisString = `
{

	"rootPackage": "reggae",

	"configuration": "executable",

	"buildType": "debug",

	"compiler": "dmd",

	"architecture": [

		"x86_64"

	],

	"platform": [

		"linux",

		"posix"

	],

	"packages": [

		{

			"path": "/home/travis/build/atilaneves/reggae/",

			"name": "reggae",

			"version": "~master",

			"description": "A build system in D",

			"homepage": "https://github.com/atilaneves/reggae",

			"authors": [

				"Atila Neves"

			],

			"copyright": "Copyright © 2015, Atila Neves",

			"license": "BSD 3-clause",

			"dependencies": [],

			"active": true,

			"configuration": "executable",

			"targetType": "executable",

			"targetPath": "bin",

			"targetName": "reggae",

			"targetFileName": "reggae",

			"workingDirectory": "",

			"mainSourceFile": "src/reggae/reggae_main.d",

			"dflags": [],

			"lflags": [],

			"libs": [],

			"copyFiles": [],

			"versions": [],

			"debugVersions": [],

			"importPaths": [

				"src",

				"payload"

			],

			"stringImportPaths": [

				"payload/reggae"

			],

			"preGenerateCommands": [],

			"postGenerateCommands": [],

			"preBuildCommands": [],

			"postBuildCommands": [],

			"buildRequirements": [],

			"options": [],

			"files": [

				{

					"role": "unusedSource",

					"path": "bin/ut.d"

				},

				{

					"role": "stringImport",

					"path": "payload/reggae/JSON.lua"

				},

				{

					"role": "stringImport",

					"path": "payload/reggae/__init__.py"

				},

				{

					"role": "source",

					"path": "payload/reggae/backend/binary.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/backend/make.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/backend/ninja.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/backend/package.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/backend/tup.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/build.d"

				},

				{

					"role": "stringImport",

					"path": "payload/reggae/build.py"

				},

				{

					"role": "source",

					"path": "payload/reggae/buildgen.d"

				},

				{

					"role": "stringImport",

					"path": "payload/reggae/buildgen_main.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/config.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/core/package.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/core/rules/package.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/ctaa.d"

				},

				{

					"role": "stringImport",

					"path": "payload/reggae/dcompile.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/dependencies.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/dub/info.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/file.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/options.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/package.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/range.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/reflect.d"

				},

				{

					"role": "stringImport",

					"path": "payload/reggae/reflect.py"

				},

				{

					"role": "stringImport",

					"path": "payload/reggae/reggae-js.js"

				},

				{

					"role": "stringImport",

					"path": "payload/reggae/reggae.lua"

				},

				{

					"role": "stringImport",

					"path": "payload/reggae/reggae.rb"

				},

				{

					"role": "stringImport",

					"path": "payload/reggae/reggae_json_build.js"

				},

				{

					"role": "stringImport",

					"path": "payload/reggae/reggae_json_build.lua"

				},

				{

					"role": "stringImport",

					"path": "payload/reggae/reggae_json_build.py"

				},

				{

					"role": "stringImport",

					"path": "payload/reggae/reggae_json_build.rb"

				},

				{

					"role": "stringImport",

					"path": "payload/reggae/rules.py"

				},

				{

					"role": "source",

					"path": "payload/reggae/rules/c_and_cpp.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/rules/common.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/rules/d.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/rules/dub.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/rules/package.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/sorting.d"

				},

				{

					"role": "source",

					"path": "payload/reggae/types.d"

				},

				{

					"role": "source",

					"path": "src/reggae/dub/call.d"

				},

				{

					"role": "source",

					"path": "src/reggae/dub/interop.d"

				},

				{

					"role": "source",

					"path": "src/reggae/dub/json.d"

				},

				{

					"role": "source",

					"path": "src/reggae/json_build.d"

				},

				{

					"role": "source",

					"path": "src/reggae/reggae.d"

				},

				{

					"role": "source",

					"path": "src/reggae/reggae_main.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/backend/binary.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/buildgen/arbitrary.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/buildgen/automatic_dependency.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/buildgen/backend_errors.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/buildgen/code_command.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/buildgen/empty_reggaefile.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/buildgen/export_.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/buildgen/implicits.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/buildgen/multiple_outputs.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/buildgen/optional.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/buildgen/outputs_in_project_path.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/buildgen/package.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/buildgen/phony.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/buildgen/reggaefile_errors.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/buildgen/two_builds_reggaefile.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/package.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/rules/json_build.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/rules/object_files.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/rules/scriptlike.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/rules/static_lib.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/rules/unity_build.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/runtime/dub.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/runtime/error_messages.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/runtime/javascript.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/runtime/lua.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/runtime/package.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/runtime/python.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/runtime/regressions.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/runtime/ruby.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/it/runtime/user_vars.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/d_and_cpp/reggaefile.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/d_and_cpp/src/constants.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/dub/imps/strings.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/dub_prebuild/source/lemaths.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/export_proj/reggaefile.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/implicits/reggaefile.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/multiple_outputs/protocol.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/multiple_outputs/reggaefile_sep.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/multiple_outputs/reggaefile_tog.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/opt/reggaefile.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/outputs_in_project_path/reggaefile.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/phony_proj/reggaefile.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/project1/reggaefile.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/project1/src/maths.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/project2/reggaefile.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/project2/source/foo.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/scriptlike/d/constants.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/scriptlike/d/logger.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/scriptlike/reggaefile.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/static_lib/libsrc/adder.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/static_lib/libsrc/muler.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/static_lib/reggaefile.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/template_rules/reggaefile.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/projects/unity/reggaefile.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/backend/binary.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/build.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/by_package.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/code_command.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/cpprules.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/ctaa.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/default_options.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/default_rules.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/dependencies.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/drules.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/dub_call.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/dub_json.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/high_rules.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/json_build/rules.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/json_build/simple.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/ninja.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/range.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/realistic_build.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/reflect.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/rules/link.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/serialisation.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/simple_bar_reggaefile.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/simple_foo_reggaefile.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/ut/tup.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/utils.d"

				}

			]

		},

		{

			"path": "/home/travis/.dub/packages/unit-threaded-0.6.14/unit-threaded/",

			"name": "unit-threaded",

			"version": "0.6.14",

			"description": "Advanced multi-threaded unit testing framework with minimal to no boilerplate using built-in unittest blocks",

			"homepage": "https://github.com/atilaneves/unit-threaded",

			"authors": [

				"Atila Neves"

			],

			"copyright": "Copyright © 2013, Atila Neves",

			"license": "BSD 3-clause",

			"dependencies": [],

			"active": false,

			"configuration": "library",

			"targetType": "library",

			"targetPath": "",

			"targetName": "unit-threaded",

			"targetFileName": "libunit-threaded.a",

			"workingDirectory": "",

			"mainSourceFile": "",

			"dflags": [],

			"lflags": [],

			"libs": [],

			"copyFiles": [],

			"versions": [],

			"debugVersions": [],

			"importPaths": [

				"source/"

			],

			"stringImportPaths": [],

			"preGenerateCommands": [],

			"postGenerateCommands": [],

			"preBuildCommands": [],

			"postBuildCommands": [],

			"buildRequirements": [],

			"options": [],

			"files": [

				{

					"role": "unusedSource",

					"path": "example/example_pass.d"

				},

				{

					"role": "unusedSource",

					"path": "gen/gen_ut_main.d"

				},

				{

					"role": "source",

					"path": "source/unit_threaded/asserts.d"

				},

				{

					"role": "source",

					"path": "source/unit_threaded/attrs.d"

				},

				{

					"role": "source",

					"path": "source/unit_threaded/dub.d"

				},

				{

					"role": "source",

					"path": "source/unit_threaded/factory.d"

				},

				{

					"role": "source",

					"path": "source/unit_threaded/integration.d"

				},

				{

					"role": "source",

					"path": "source/unit_threaded/io.d"

				},

				{

					"role": "source",

					"path": "source/unit_threaded/meta.d"

				},

				{

					"role": "source",

					"path": "source/unit_threaded/options.d"

				},

				{

					"role": "source",

					"path": "source/unit_threaded/package.d"

				},

				{

					"role": "source",

					"path": "source/unit_threaded/reflection.d"

				},

				{

					"role": "source",

					"path": "source/unit_threaded/runner.d"

				},

				{

					"role": "source",

					"path": "source/unit_threaded/runtime.d"

				},

				{

					"role": "source",

					"path": "source/unit_threaded/should.d"

				},

				{

					"role": "source",

					"path": "source/unit_threaded/testcase.d"

				},

				{

					"role": "source",

					"path": "source/unit_threaded/tests/module_with_attrs.d"

				},

				{

					"role": "source",

					"path": "source/unit_threaded/tests/module_with_tests.d"

				},

				{

					"role": "source",

					"path": "source/unit_threaded/tests/parametrized.d"

				},

				{

					"role": "source",

					"path": "source/unit_threaded/tests/tags.d"

				},

				{

					"role": "source",

					"path": "source/unit_threaded/testsuite.d"

				},

				{

					"role": "source",

					"path": "source/unit_threaded/uda.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/pass/attributes.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/pass/delayed.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/pass/fixtures.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/pass/io.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/pass/normal.d"

				},

				{

					"role": "unusedSource",

					"path": "tests/pass/register.d"

				}

			]

		}

	],

	"targets": [

		{

			"rootPackage": "reggae",

			"packages": [

				"reggae"

			],

			"rootConfiguration": "executable",

			"buildSettings": {

				"targetType": 2,

				"targetPath": "/home/travis/build/atilaneves/reggae/bin",

				"targetName": "reggae",

				"workingDirectory": "",

				"mainSourceFile": "/home/travis/build/atilaneves/reggae/src/reggae/reggae_main.d",

				"dflags": [],

				"lflags": [],

				"libs": [],

				"linkerFiles": [],

				"sourceFiles": [

					"/home/travis/build/atilaneves/reggae/payload/reggae/backend/binary.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/backend/make.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/backend/ninja.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/backend/package.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/backend/tup.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/build.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/buildgen.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/config.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/core/package.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/core/rules/package.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/ctaa.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/dependencies.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/dub/info.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/file.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/options.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/package.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/range.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/reflect.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/rules/c_and_cpp.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/rules/common.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/rules/d.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/rules/dub.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/rules/package.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/sorting.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/types.d",

					"/home/travis/build/atilaneves/reggae/src/reggae/dub/call.d",

					"/home/travis/build/atilaneves/reggae/src/reggae/dub/interop.d",

					"/home/travis/build/atilaneves/reggae/src/reggae/dub/json.d",

					"/home/travis/build/atilaneves/reggae/src/reggae/json_build.d",

					"/home/travis/build/atilaneves/reggae/src/reggae/reggae.d",

					"/home/travis/build/atilaneves/reggae/src/reggae/reggae_main.d"

				],

				"copyFiles": [],

				"versions": [

					"Have_reggae"

				],

				"debugVersions": [],

				"importPaths": [

					"/home/travis/build/atilaneves/reggae/src",

					"/home/travis/build/atilaneves/reggae/payload"

				],

				"stringImportPaths": [

					"/home/travis/build/atilaneves/reggae/payload/reggae"

				],

				"importFiles": [],

				"stringImportFiles": [

					"/home/travis/build/atilaneves/reggae/payload/reggae/JSON.lua",

					"/home/travis/build/atilaneves/reggae/payload/reggae/__init__.py",

					"/home/travis/build/atilaneves/reggae/payload/reggae/backend/binary.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/backend/make.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/backend/ninja.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/backend/package.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/backend/tup.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/build.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/build.py",

					"/home/travis/build/atilaneves/reggae/payload/reggae/buildgen.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/buildgen_main.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/config.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/ctaa.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/dcompile.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/dependencies.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/dub/info.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/file.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/options.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/range.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/reflect.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/reflect.py",

					"/home/travis/build/atilaneves/reggae/payload/reggae/reggae-js.js",

					"/home/travis/build/atilaneves/reggae/payload/reggae/reggae.lua",

					"/home/travis/build/atilaneves/reggae/payload/reggae/reggae.rb",

					"/home/travis/build/atilaneves/reggae/payload/reggae/reggae_json_build.js",

					"/home/travis/build/atilaneves/reggae/payload/reggae/reggae_json_build.lua",

					"/home/travis/build/atilaneves/reggae/payload/reggae/reggae_json_build.py",

					"/home/travis/build/atilaneves/reggae/payload/reggae/reggae_json_build.rb",

					"/home/travis/build/atilaneves/reggae/payload/reggae/rules.py",

					"/home/travis/build/atilaneves/reggae/payload/reggae/rules/c_and_cpp.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/rules/common.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/rules/d.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/rules/dub.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/sorting.d",

					"/home/travis/build/atilaneves/reggae/payload/reggae/types.d"

				],

				"preGenerateCommands": [],

				"postGenerateCommands": [],

				"preBuildCommands": [],

				"postBuildCommands": [],

				"requirements": [],

				"options": [

					"debugMode",

					"debugInfo",

					"warningsAsErrors"

				]

			},

			"dependencies": [],

			"linkDependencies": []

		}

	]

}
`;

@("travis string")
unittest {
    getDubInfo(travisString);
}
