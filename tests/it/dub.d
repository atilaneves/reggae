module tests.it.dub;

import unit_threaded;

@("describe")
@Tags(["dub"])
unittest {

    import std.string: join;
    import std.algorithm: find;
    import std.format: format;
    import std.process;

    const string[string] env = null;
    Config config = Config.none;
    size_t maxOutput = size_t.max;

    with(immutable Sandbox()) {
        writeFile("dub.sdl",
                  [
                      `name "foo"`,
                      `targetType "executable"`,
                      `dependency "bar" path="bar"`
                  ].join("\n"));

        writeFile("source/app.d",
                  [
                      `void main() {`,
                      `    import bar;`,
                      `    lebar;`,
                      `}`,
                  ]);

        writeFile("bar/dub.sdl",
                  [
                      `name "bar"`,
                      `targetType "library"`,
                      ].join("\n"));


        writeFile("bar/source/bar.d",
                  [
                      `module bar;`,
                      `void lebar() {}`,
                  ]);

        const ret = execute(["dub", "describe"], env, config, maxOutput, testPath);
        if(ret.status != 0)
            throw new Exception("Could not call dub describe:\n" ~ ret.output);

        ret.output.find("{").shouldBeSameJsonAs(
            q{
                {
                    "rootPackage": "foo",
                    "configuration": "application",
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
                            "path": "%s/",
                            "name": "foo",
                            "version": "~master",
                            "description": "",
                            "homepage": "",
                            "authors": [],
                            "copyright": "",
                            "license": "",
                            "dependencies": [
                                "bar"
                            ],
                            "active": true,
                            "configuration": "application",
                            "targetType": "executable",
                            "targetPath": "",
                            "targetName": "foo",
                            "targetFileName": "foo",
                            "workingDirectory": "",
                            "mainSourceFile": "source/app.d",
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
                                    "role": "source",
                                    "path": "source/app.d"
                                }
                            ]
                        },
                        {
                            "path": "%s/bar/",
                            "name": "bar",
                            "version": "~master",
                            "description": "",
                            "homepage": "",
                            "authors": [],
                            "copyright": "",
                            "license": "",
                            "dependencies": [],
                            "active": true,
                            "configuration": "library",
                            "targetType": "library",
                            "targetPath": "",
                            "targetName": "bar",
                            "targetFileName": "libbar.a",
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
                                    "role": "source",
                                    "path": "source/bar.d"
                                }
                            ]
                        }
                    ],
                    "targets": [
                        {
                            "rootPackage": "foo",
                            "packages": [
                                "foo"
                            ],
                            "rootConfiguration": "application",
                            "buildSettings": {
                            "targetType": 2,
                            "targetPath": "%s",
                            "targetName": "foo",
                            "workingDirectory": "",
                            "mainSourceFile": "%s/source/app.d",
                            "dflags": [],
                            "lflags": [],
                            "libs": [],
                            "linkerFiles": [
                                "%s/bar/libbar.a"
                            ],
                            "sourceFiles": [
                                "%s/source/app.d"
                            ],
                            "copyFiles": [],
                            "versions": [
                                "Have_foo",
                                "Have_bar"
                            ],
                            "debugVersions": [],
                            "importPaths": [
                                "%s/source/",
                                "%s/bar/source/"
                            ],
                            "stringImportPaths": [],
                            "importFiles": [],
                            "stringImportFiles": [],
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
                        "dependencies": [
                            "bar"
                        ],
                        "linkDependencies": [
                            "bar"
                        ]
                        },
                        {
                            "rootPackage": "bar",
                            "packages": [
                                "bar"
                            ],
                            "rootConfiguration": "library",
                            "buildSettings": {
                                "targetType": 6,
                                "targetPath": "%s/bar",
                                "targetName": "bar",
                                "workingDirectory": "",
                                "mainSourceFile": "",
                                "dflags": [],
                                "lflags": [],
                                "libs": [],
                                "linkerFiles": [],
                                "sourceFiles": [
                                    "%s/bar/source/bar.d"
                                ],
                                "copyFiles": [],
                                "versions": [
                                    "Have_bar"
                                ],
                                "debugVersions": [],
                                "importPaths": [
                                    "%s/bar/source/"
                                ],
                                "stringImportPaths": [],
                                "importFiles": [],
                                "stringImportFiles": [],
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
        }.format(testPath, testPath, testPath, testPath, testPath, testPath, testPath, testPath, testPath, testPath, testPath));
    }
}
