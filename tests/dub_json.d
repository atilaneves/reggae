module tests.dub_json;


import unit_threaded;
import reggae;
import reggae.dub.json;


immutable jsonString =
    `WARNING: A deprecated branch based version specification is used for the dependency unit-threaded. Please use numbered versions instead. Also note that you can still use the dub.selections.json file to override a certain dependency to use a branch instead.`
    `{`
    `  "packages": [`
    `    {`
    `      "targetType": "executable",`
    `      "path": "/path/to/pkg1",`
    `      "name": "pkg1",`
    `      "mainSourceFile": "src/boooo.d",`
    `      "targetFileName": "super_app",`
    `      "dflags": [],`
    `      "versions": ["v1", "v2"],`
    `      "dependencies": ["pkg_other"],`
    `      "importPaths": ["leimports"],`
    `      "stringImportPaths": [`
    `        "src/string_imports",`
    `        "src/moar_stringies"`
    `      ],`
    `      "active": true,`
    `      "preBuildCommands": ["dub run dtest"],`
    `      "files": [`
    `        {`
    `          "path": "src/foo.d",`
    `          "type": "source"`
    `        },`
    `        {`
    `          "path": "src/bar.d",`
    `          "type": "source"`
    `        },`
    `        {`
    `          "path": "src/boooo.d",`
    `          "type": "source"`
    `        }`
    `      ]`
    `    },`
    `    {`
    `      "path": "/weird/path/pkg_other",`
    `      "name": "pkg_other",`
    `      "importPaths": [`
    `        "my_imports",`
    `        "moar_imports"`
    `      ],`
    `      "dflags": [`
    `        "-g", "-debug"`
    `      ],`
    `      "libs": ["liblib", "otherlib"],`
    `      "versions": ["v3", "v4"],`
    `      "stringImportPaths": [],`
    `      "active": true,`
    `      "files": [`
    `        {`
    `          "path": "source/toto.d",`
    `          "type": "source"`
    `        },`
    `        {`
    `          "path": "source/africa.d",`
    `          "type": "source"`
    `        },`
    `        {`
    `          "path": "source/africa.d",`
    `          "type": "weirdo"`
    `        }`
    `      ]`
    `    }`
    `  ]`
    `}`;


void testJsonToDubDescribe() {
    const info = getDubInfo(jsonString.dup);
    info.shouldEqual(
        DubInfo(
            [DubPackage("pkg1", "/path/to/pkg1", "src/boooo.d", "super_app",
                        [],
                        ["leimports"],
                        ["src/string_imports", "src/moar_stringies"],
                        ["src/foo.d", "src/bar.d", "src/boooo.d"],
                        "executable", ["v1", "v2"], ["pkg_other"], [], true, ["dub run dtest"]),

             DubPackage("pkg_other", "/weird/path/pkg_other", "", "",
                        ["-g", "-debug"],
                        ["my_imports", "moar_imports"],
                        [],
                        ["source/toto.d", "source/africa.d"],
                        "", ["v3", "v4"], [], ["liblib", "otherlib"], true)]));
}

void testDubInfoToTargets() {
    const info = getDubInfo(jsonString.dup);
    info.toTargets[0].shouldEqual(
        Target("path/to/pkg1/src/foo.o",
               Command(CommandType.compile,
                       assocListT("includes", ["-I/path/to/pkg1/leimports",
                                               "-I/weird/path/pkg_other/my_imports",
                                               "-I/weird/path/pkg_other/moar_imports",
                                               "-I"],
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
                                               "-I"],
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
                                               "-I/weird/path/pkg_other"],
                                  "flags", ["-g", "-debug", "-version=v3", "-version=v4"],
                                  "stringImports", cast(string[])[],
                                  "DEPFILE", ["weird/path/pkg_other/source/toto.o.dep"])),
               Target("/weird/path/pkg_other/source/toto.d")),

        );

}


@ShouldFail("old command style")
void testDubInfoToTargetsLib() {
    const info = getDubInfo(jsonString.replace("executable", "library"));
    info.mainTarget.shouldEqual(
        Target("super_app", "_link flags=-lib,-L-lliblib,-L-lotherlib",
               [Target("path/to/pkg1/src/foo.o",
                       "_dcompile "
                       "includes=-I/path/to/pkg1/leimports,-I/weird/path/pkg_other/my_imports,"
                       "-I/weird/path/pkg_other/moar_imports "
                       "flags=-version=v1,-version=v2,-version=v3,-version=v4 "
                       "stringImports=-J/path/to/pkg1/src/string_imports,-J/path/to/pkg1/src/moar_stringies",
                       [Target("/path/to/pkg1/src/foo.d")]),
                Target("path/to/pkg1/src/bar.o",
                       "_dcompile "
                       "includes=-I/path/to/pkg1/leimports,-I/weird/path/pkg_other/my_imports,"
                       "-I/weird/path/pkg_other/moar_imports "
                       "flags=-version=v1,-version=v2,-version=v3,-version=v4 "
                       "stringImports=-J/path/to/pkg1/src/string_imports,-J/path/to/pkg1/src/moar_stringies",
                       [Target("/path/to/pkg1/src/bar.d")]),
                Target("path/to/pkg1/src/boooo.o",
                       "_dcompile "
                       "includes=-I/path/to/pkg1/leimports,-I/weird/path/pkg_other/my_imports,"
                       "-I/weird/path/pkg_other/moar_imports "
                       "flags=-version=v1,-version=v2,-version=v3,-version=v4 "
                       "stringImports=-J/path/to/pkg1/src/string_imports,-J/path/to/pkg1/src/moar_stringies",
                       [Target("/path/to/pkg1/src/boooo.d")]),
                Target("weird/path/pkg_other/source/toto.o",
                       "_dcompile "
                       "includes=-I/weird/path/pkg_other/my_imports,-I/weird/path/pkg_other/moar_imports "
                       "flags=-g,-debug,-version=v3,-version=v4 stringImports=",
                       [Target("/weird/path/pkg_other/source/toto.d")]),
                Target("weird/path/pkg_other/source/africa.o",
                       "_dcompile "
                       "includes=-I/weird/path/pkg_other/my_imports,-I/weird/path/pkg_other/moar_imports "
                       "flags=-g,-debug,-version=v3,-version=v4 stringImports=",
                       [Target("/weird/path/pkg_other/source/africa.d")]),
                   ]));
}


@ShouldFail("old command style")
void testDubInfoWithLibs() {
    const info = getDubInfo(jsonString.dup);
    info.mainTarget.shouldEqual(
        Target("super_app", "_link flags=-L-lliblib,-L-lotherlib",
               [Target("path/to/pkg1/src/foo.o",
                       "_dcompile "
                       "includes=-I/path/to/pkg1/leimports,-I/weird/path/pkg_other/my_imports,"
                       "-I/weird/path/pkg_other/moar_imports "
                       "flags=-version=v1,-version=v2,-version=v3,-version=v4 "
                       "stringImports=-J/path/to/pkg1/src/string_imports,-J/path/to/pkg1/src/moar_stringies",
                       [Target("/path/to/pkg1/src/foo.d")]),
                Target("path/to/pkg1/src/bar.o",
                       "_dcompile "
                       "includes=-I/path/to/pkg1/leimports,-I/weird/path/pkg_other/my_imports,"
                       "-I/weird/path/pkg_other/moar_imports "
                       "flags=-version=v1,-version=v2,-version=v3,-version=v4 "
                       "stringImports=-J/path/to/pkg1/src/string_imports,-J/path/to/pkg1/src/moar_stringies",
                       [Target("/path/to/pkg1/src/bar.d")]),
                Target("path/to/pkg1/src/boooo.o",
                       "_dcompile "
                       "includes=-I/path/to/pkg1/leimports,-I/weird/path/pkg_other/my_imports,"
                       "-I/weird/path/pkg_other/moar_imports "
                       "flags=-version=v1,-version=v2,-version=v3,-version=v4 "
                       "stringImports=-J/path/to/pkg1/src/string_imports,-J/path/to/pkg1/src/moar_stringies",
                       [Target("/path/to/pkg1/src/boooo.d")]),
                Target("weird/path/pkg_other/source/toto.o",
                       "_dcompile "
                       "includes=-I/weird/path/pkg_other/my_imports,-I/weird/path/pkg_other/moar_imports "
                       "flags=-g,-debug,-version=v3,-version=v4 stringImports=",
                       [Target("/weird/path/pkg_other/source/toto.d")]),
                Target("weird/path/pkg_other/source/africa.o",
                       "_dcompile "
                       "includes=-I/weird/path/pkg_other/my_imports,-I/weird/path/pkg_other/moar_imports "
                       "flags=-g,-debug,-version=v3,-version=v4 stringImports=",
                       [Target("/weird/path/pkg_other/source/africa.d")]),
                   ]));
}


void testDubFetch() {
    const info = getDubInfo(jsonString.dup);
    info.fetchCommands.shouldEqual(
        [["dub", "fetch", "pkg_other"]]);
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
