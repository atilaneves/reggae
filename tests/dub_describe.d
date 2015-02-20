module tests.dub_describe;


import unit_threaded;
import reggae;


auto jsonString =
    `{`
    `  "packages": [`
    `    {`
    `      "path": "/path/to/pkg1",`
    `      "name": "pkg1",`
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
                            ["src/foo.d", "src/bar.d"]),
                 DubPackage("pkg_other", "/weird/path/pkg_other",
                            ["source/toto.d", "source/africa.d"])]));
}


void testDubInfoToTargets() {
    const info = dubInfo(jsonString.dup);
    const targets = dubInfoToTargets(info);
    targets.shouldEqual(
        [Target("foo.d.o", "_dcompile ", [Target("/path/to/pkg1/src/foo.d")]),
         Target("bar.d.o", "_dcompile ", [Target("/path/to/pkg1/src/bar.d")]),
         Target("toto.d.o", "_dcompile ", [Target("/weird/path/pkg_other/source/todo.d")]),
         Target("africa.d.o", "_dcompile ", [Target("/weird/path/pkg_other/source/africa.d")]),
            ]);
}
