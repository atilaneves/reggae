module tests.dub_describe;


import unit_threaded;
import reggae;
import stdx.data.json;


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
    immutable info = dubInfo(jsonString);
    info.shouldEqual(
        DubInfo([DubPackage("pkg1", "/path/to/pkg1",
                            ["src/foo.d", "src/bar.d"]),
                 DubPackage("pkg_other", "/weird/path/pkg_other",
                            ["source/todo.d", "source/africa.d"])]));
}
