module tests.dub_describe;


import unit_threaded;
import reggae;
import reggae.dub_json;


auto jsonString =
    `{`
    `  "packages": [`
    `    {`
    `      "path": "/path/to/pkg1",`
    `      "name": "pkg1",`
    `      "dflags": [],`
    `      "importPaths": [],`
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
    `      "stringImportPaths": [],`
    `      "files": [`
    `        {`
    `          "path": "source/toto.d",`
    `          "type": "source"`
    `        },`
    `        {`
    `          "path": "source/africa.d",`
    `          "type": "source"`
    `        }`
    `      ]`
    `    }`
    `  ]`
    `}`;

void testJsonToDubDescribe() {
    const info = dubInfo(jsonString.dup);
    info.shouldEqual(
        DubInfo([DubPackage("pkg1", "/path/to/pkg1",
                            [],
                            [],
                            ["src/string_imports", "src/moar_stringies"],
                            ["src/foo.d", "src/bar.d"]),
                 DubPackage("pkg_other", "/weird/path/pkg_other",
                            ["-g", "-debug"],
                            ["my_imports", "moar_imports"],
                            [],
                            ["source/toto.d", "source/africa.d"])]));
}


void testDubInfoToTargets() {
    const info = dubInfo(jsonString.dup);
    const targets = dubInfoToTargets(info);
    targets.shouldEqual(
        [Target("foo.o",
                "_dcompile  includes= flags= "
                "stringImports=-J/path/to/pkg1/src/string_imports,-J/path/to/pkg1/src/moar_stringies",
                [Target("/path/to/pkg1/src/foo.d")]),
         Target("bar.o",
                "_dcompile  includes= flags= "
                "stringImports=-J/path/to/pkg1/src/string_imports,-J/path/to/pkg1/src/moar_stringies",
                [Target("/path/to/pkg1/src/bar.d")]),
         Target("toto.o",
                "_dcompile  "
                "includes=-I/weird/path/pkg_other/my_imports,-I/weird/path/pkg_other/moar_imports "
                "flags=-g,-debug stringImports=",
                [Target("/weird/path/pkg_other/source/toto.d")]),
         Target("africa.o",
                "_dcompile  "
                "includes=-I/weird/path/pkg_other/my_imports,-I/weird/path/pkg_other/moar_imports "
                "flags=-g,-debug stringImports=",
                [Target("/weird/path/pkg_other/source/africa.d")]),
            ]);
}
