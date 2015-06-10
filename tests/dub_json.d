module tests.dub_json;


import unit_threaded;
import reggae;
import reggae.dub.json;


auto jsonString =
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
    `      "files": [`
    `        {`
    `          "path": "src/foo.d",`
    `          "type": "source",`
    `          "active": true`
    `        },`
    `        {`
    `          "path": "src/bar.d",`
    `          "type": "source",`
    `          "active": true`
    `        },`
    `        {`
    `          "path": "src/boooo.d",`
    `          "type": "source",`
    `          "active": true`
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
    `      "files": [`
    `        {`
    `          "path": "source/toto.d",`
    `          "type": "source",`
    `          "active": true`
    `        },`
    `        {`
    `          "path": "source/africa.d",`
    `          "type": "source",`
    `          "active": true`
    `        },`
    `        {`
    `          "path": "source/africa.d",`
    `          "type": "weirdo",`
    `          "active": true`
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
                        "executable", ["v1", "v2"], ["pkg_other"]),

             DubPackage("pkg_other", "/weird/path/pkg_other", "", "",
                        ["-g", "-debug"],
                        ["my_imports", "moar_imports"],
                        [],
                        ["source/toto.d", "source/africa.d"],
                        "", ["v3", "v4"], [], ["liblib", "otherlib"])]));
}


void testDubInfoToTargets() {
    const info = getDubInfo(jsonString.dup);
    info.toTargets.shouldEqual(
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
            ]);

    info.toTargets(No.main).shouldEqual(
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
            ]);
}


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
