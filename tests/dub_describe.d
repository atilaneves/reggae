module tests.dub_describe;


import unit_threaded;
import reggae;
import reggae.dub_json;


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
    `      "versions": ["v3", "v4"],`
    `      "stringImportPaths": [],`
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
    const info = dubInfo(jsonString.dup);
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
                        "", ["v3", "v4"])]));
}


void testDubInfoToTargets() {
    const info = dubInfo(jsonString.dup);
    info.toTargets.shouldEqual(
        [Target("path/to/pkg1/src/foo.o",
                "_dcompile  "
                "includes=-I/path/to/pkg1/leimports,-I/weird/path/pkg_other/my_imports,"
                "-I/weird/path/pkg_other/moar_imports "
                "flags=-version=v1,-version=v2,-version=v3,-version=v4 "
                "stringImports=-J/path/to/pkg1/src/string_imports,-J/path/to/pkg1/src/moar_stringies",
                [Target("/path/to/pkg1/src/foo.d")]),
         Target("path/to/pkg1/src/bar.o",
                "_dcompile  "
                "includes=-I/path/to/pkg1/leimports,-I/weird/path/pkg_other/my_imports,"
                "-I/weird/path/pkg_other/moar_imports "
                "flags=-version=v1,-version=v2,-version=v3,-version=v4 "
                "stringImports=-J/path/to/pkg1/src/string_imports,-J/path/to/pkg1/src/moar_stringies",
                [Target("/path/to/pkg1/src/bar.d")]),
         Target("path/to/pkg1/src/boooo.o",
                "_dcompile  "
                "includes=-I/path/to/pkg1/leimports,-I/weird/path/pkg_other/my_imports,"
                "-I/weird/path/pkg_other/moar_imports "
                "flags=-version=v1,-version=v2,-version=v3,-version=v4 "
                "stringImports=-J/path/to/pkg1/src/string_imports,-J/path/to/pkg1/src/moar_stringies",
                [Target("/path/to/pkg1/src/boooo.d")]),
         Target("weird/path/pkg_other/source/toto.o",
                "_dcompile  "
                "includes=-I/weird/path/pkg_other/my_imports,-I/weird/path/pkg_other/moar_imports "
                "flags=-g,-debug,-version=v3,-version=v4 stringImports=",
                [Target("/weird/path/pkg_other/source/toto.d")]),
         Target("weird/path/pkg_other/source/africa.o",
                "_dcompile  "
                "includes=-I/weird/path/pkg_other/my_imports,-I/weird/path/pkg_other/moar_imports "
                "flags=-g,-debug,-version=v3,-version=v4 stringImports=",
                [Target("/weird/path/pkg_other/source/africa.d")]),
            ]);

    info.toTargets(No.main).shouldEqual(
        [Target("path/to/pkg1/src/foo.o",
                "_dcompile  "
                "includes=-I/path/to/pkg1/leimports,-I/weird/path/pkg_other/my_imports,"
                "-I/weird/path/pkg_other/moar_imports "
                "flags=-version=v1,-version=v2,-version=v3,-version=v4 "
                "stringImports=-J/path/to/pkg1/src/string_imports,-J/path/to/pkg1/src/moar_stringies",
                [Target("/path/to/pkg1/src/foo.d")]),
         Target("path/to/pkg1/src/bar.o",
                "_dcompile  "
                "includes=-I/path/to/pkg1/leimports,-I/weird/path/pkg_other/my_imports,"
                "-I/weird/path/pkg_other/moar_imports "
                "flags=-version=v1,-version=v2,-version=v3,-version=v4 "
                "stringImports=-J/path/to/pkg1/src/string_imports,-J/path/to/pkg1/src/moar_stringies",
                [Target("/path/to/pkg1/src/bar.d")]),
         Target("weird/path/pkg_other/source/toto.o",
                "_dcompile  "
                "includes=-I/weird/path/pkg_other/my_imports,-I/weird/path/pkg_other/moar_imports "
                "flags=-g,-debug,-version=v3,-version=v4 stringImports=",
                [Target("/weird/path/pkg_other/source/toto.d")]),
         Target("weird/path/pkg_other/source/africa.o",
                "_dcompile  "
                "includes=-I/weird/path/pkg_other/my_imports,-I/weird/path/pkg_other/moar_imports "
                "flags=-g,-debug,-version=v3,-version=v4 stringImports=",
                [Target("/weird/path/pkg_other/source/africa.d")]),
            ]);
}


void testDubInfoToTargetsLib() {
    const info = dubInfo(jsonString.replace("executable", "library"));
    info.target.shouldEqual(
        Target("super_app", "_dlink flags=-lib",
               [Target("path/to/pkg1/src/foo.o",
                       "_dcompile  "
                       "includes=-I/path/to/pkg1/leimports,-I/weird/path/pkg_other/my_imports,"
                       "-I/weird/path/pkg_other/moar_imports "
                       "flags=-version=v1,-version=v2,-version=v3,-version=v4 "
                       "stringImports=-J/path/to/pkg1/src/string_imports,-J/path/to/pkg1/src/moar_stringies",
                       [Target("/path/to/pkg1/src/foo.d")]),
                Target("path/to/pkg1/src/bar.o",
                       "_dcompile  "
                       "includes=-I/path/to/pkg1/leimports,-I/weird/path/pkg_other/my_imports,"
                       "-I/weird/path/pkg_other/moar_imports "
                       "flags=-version=v1,-version=v2,-version=v3,-version=v4 "
                       "stringImports=-J/path/to/pkg1/src/string_imports,-J/path/to/pkg1/src/moar_stringies",
                       [Target("/path/to/pkg1/src/bar.d")]),
                Target("path/to/pkg1/src/boooo.o",
                       "_dcompile  "
                       "includes=-I/path/to/pkg1/leimports,-I/weird/path/pkg_other/my_imports,"
                       "-I/weird/path/pkg_other/moar_imports "
                       "flags=-version=v1,-version=v2,-version=v3,-version=v4 "
                       "stringImports=-J/path/to/pkg1/src/string_imports,-J/path/to/pkg1/src/moar_stringies",
                       [Target("/path/to/pkg1/src/boooo.d")]),
                Target("weird/path/pkg_other/source/toto.o",
                       "_dcompile  "
                       "includes=-I/weird/path/pkg_other/my_imports,-I/weird/path/pkg_other/moar_imports "
                       "flags=-g,-debug,-version=v3,-version=v4 stringImports=",
                       [Target("/weird/path/pkg_other/source/toto.d")]),
                Target("weird/path/pkg_other/source/africa.o",
                       "_dcompile  "
                       "includes=-I/weird/path/pkg_other/my_imports,-I/weird/path/pkg_other/moar_imports "
                       "flags=-g,-debug,-version=v3,-version=v4 stringImports=",
                       [Target("/weird/path/pkg_other/source/africa.d")]),
                   ]));
}
