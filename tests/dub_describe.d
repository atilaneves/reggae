module tests.dub_describe;


import unit_threaded;
import reggae;
import stdx.data.json;


auto jsonString =
    `{`
    `  "packages": [`
    `    {`
    `      "path": "/path/to/pkg1",`
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
    `      "path": "/path/to/pkg_other",`
    `      "files": [`
    `        {`
    `          "path": "src/toto.d",`
    `          "type": "source"`
    `        },`
    `        {`
    `          "path": "src/africa.d",`
    `          "type": "source"`
    `        }`
    `      ]`
    `    }`
    `  ]`
    `}`;

void testDubDescribe() {
    auto json = parseJSONValue(jsonString);
    auto packages = json.get!(JSONValue[string])["packages"];
    packages.length.shouldEqual(2);
}
