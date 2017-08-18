module tests.ut.dub.json;


import unit_threaded;
import reggae;
import reggae.dub.json;
import std.string;

@("foobar.json gets parsed correctly")
unittest {
    import std.format: format;
    const path = "/path/to";
    const info = getDubInfo(import("foobar.json").format(path, path, path, path, path, path, path, path, path, path, path));
    info.shouldEqual(
        DubInfo(
            [
                DubPackage(
                    "foo", //name
                    "/path/to/", //path
                    "/path/to/source/app.d", // mainSourceFile
                    "foo", // targetFileName
                    [], // dflags
                    [], // lflags
                    ["/path/to/source/", "/path/to/bar/source/"], // importPaths
                    [], // stringImportPaths
                    ["/path/to/source/app.d"], // sourceFiles
                    TargetType.executable,
                    ["lefoo", "Have_foo", "Have_bar"], // versions
                    ["bar"], // dependencies
                    [], // libs
                    true, // active
                    [], // preBuildCommands
                    [], //postBuildCommands
                ),
                DubPackage(
                    "bar", //name
                    "/path/to/bar/", //path
                    "", // mainSourceFile
                    "bar", // targetFileName
                    [], // dflags
                    [], // lflags
                    ["/path/to/bar/source/"], // importPaths
                    [], // stringImportPaths
                    ["/path/to/bar/source/bar.d"], // sourceFiles
                    TargetType.staticLibrary,
                    ["lefoo", "Have_bar"], // versions
                    [], // dependencies
                    [], // libs
                    true, // active
                    [], // preBuildCommands
                    [], //postBuildCommands
                ),
            ]
        )
    );
}

@("DubInfo.targetName")
unittest {
    import std.format: format;
    const path = "/path/to";
    auto info = getDubInfo(import("foobar.json").format(path, path, path, path, path, path, path, path, path, path, path));

    info.targetName.shouldEqual(TargetName("foo"));

    info.packages[0].targetType = TargetType.dynamicLibrary;
    info.targetName.shouldEqual(TargetName("libfoo.so"));

    info.packages[0].targetType = TargetType.library;
    info.targetName.shouldEqual(TargetName("libfoo.a"));
}

@("PACKAGE_DIR")
unittest {
    const jsonString = q{
        {
            "packages": [
                {
                    "name": "lepackage",
                    "path": "/dub/packages/lepackage",
                    "files": [
                        {"role": "source", "path": "$PACKAGE_DIR/foo.o"},
                        {"role": "source", "path": "src/file.d"}
                    ]
                },
                {
                    "name": "dep",
                    "path": "/dub/packages/dep",
                    "files": [
                        {"role": "source", "path": "$PACKAGE_DIR/bar.o"},
                        {"role": "source", "path": "src/dep.d"}
                    ]
                }
            ],
            "targets": [
                {
                    "rootPackage": "lepackage",
                    "buildSettings": {
                        "targetName": "lepackage",
                        "targetPath": "/dub/packages/lepackage",
                        "dflags": [],
                        "lflags": ["-L$PACKAGE_DIR"],
                        "importPaths": ["$PACKAGE_DIR/imports"],
                        "stringImportPaths": ["$PACKAGE_DIR/stringImports"],
                        "sourceFiles": [
                            "$PACKAGE_DIR/foo.o",
                            "src/file.d"
                        ]
                    }
                },
                {
                    "rootPackage": "dep",
                    "buildSettings": {
                        "targetName": "dep",
                        "targetPath": "/dub/packages/dep",
                        "dflags": [],
                        "lflags": [],
                        "importPaths": [],
                        "stringImportPaths": [],
                        "sourceFiles": [
                            "$PACKAGE_DIR/bar.o",
                            "src/dep.d"
                        ]
                    }
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
                    "lepackage", // targetFileName
                    [], // dflags
                    ["-L/dub/packages/lepackage"],
                    ["/dub/packages/lepackage/imports"],
                    ["/dub/packages/lepackage/stringImports"],
                    ["/dub/packages/lepackage/foo.o", "src/file.d"],
                    TargetType.autodetect, // targetType
                    [], // versions
                    [], // dependencies
                    [], // libs
                    true, // active
                ),
                DubPackage(
                    "dep",
                    "/dub/packages/dep",
                    "", // mainSourceFile
                    "dep", //targetFileName
                    [], // dflags
                    [], // lflags
                    [], // importPaths
                    [], // stringImportPaths
                    ["/dub/packages/dep/bar.o", "src/dep.d"],
                    TargetType.autodetect, // targetType
                    [], // versions
                    [], // dependencies
                    [], // libs
                    true, // active
                ),
            ]
    ));
}

@("remove object file duplicates")
unittest {
   const info = DubInfo(
       [
           DubPackage(
               "foo", //name
               "/path/to/", //path
               "/path/to/source/app.d", // mainSourceFile
               "foo", // targetFileName
               [], // dflags
               [], // lflags
               ["/path/to/source/", "/path/to/bar/source/"], // importPaths
               [], // stringImportPaths
               ["/path/to/source/app.d", "baz.o"], // sourceFiles
               TargetType.executable,
               ["lefoo", "Have_foo", "Have_bar"], // versions
               ["bar"], // dependencies
               [], // libs
               true, // active
               [], // preBuildCommands
               [], //postBuildCommands
           ),
           DubPackage(
               "bar", //name
               "/path/to/bar/", //path
               "", // mainSourceFile
               "bar", // targetFileName
               [], // dflags
               [], // lflags
               ["/path/to/bar/source/"], // importPaths
               [], // stringImportPaths
               ["/path/to/bar/source/bar.d", "baz.o"], // sourceFiles
               TargetType.staticLibrary,
               ["lefoo", "Have_bar"], // versions
               [], // dependencies
               [], // libs
               true, // active
               [], // preBuildCommands
               [], //postBuildCommands
           ),
       ]
   );

   info.cleanObjectSourceFiles.shouldEqual(DubInfo(
       [
           DubPackage(
               "foo", //name
               "/path/to/", //path
               "/path/to/source/app.d", // mainSourceFile
               "foo", // targetFileName
               [], // dflags
               [], // lflags
               ["/path/to/source/", "/path/to/bar/source/"], // importPaths
               [], // stringImportPaths
               ["/path/to/source/app.d"], // sourceFiles
               TargetType.executable,
               ["lefoo", "Have_foo", "Have_bar"], // versions
               ["bar"], // dependencies
               [], // libs
               true, // active
               [], // preBuildCommands
               [], //postBuildCommands
           ),
           DubPackage(
               "bar", //name
               "/path/to/bar/", //path
               "", // mainSourceFile
               "bar", // targetFileName
               [], // dflags
               [], // lflags
               ["/path/to/bar/source/"], // importPaths
               [], // stringImportPaths
               ["/path/to/bar/source/bar.d", "baz.o"], // sourceFiles
               TargetType.staticLibrary,
               ["lefoo", "Have_bar"], // versions
               [], // dependencies
               [], // libs
               true, // active
               [], // preBuildCommands
               [], //postBuildCommands
           ),
       ]
   ));
}

@("cleanObjectSourceFiles with no duplicates")
unittest {
   const info = DubInfo(
       [
           DubPackage(
               "foo", //name
               "/path/to/", //path
               "/path/to/source/app.d", // mainSourceFile
               "foo", // targetFileName
               [], // dflags
               [], // lflags
               ["/path/to/source/", "/path/to/bar/source/"], // importPaths
               [], // stringImportPaths
               ["/path/to/source/app.d", "baz.o"], // sourceFiles
               TargetType.executable,
               ["lefoo", "Have_foo", "Have_bar"], // versions
               ["bar"], // dependencies
               [], // libs
               true, // active
               [], // preBuildCommands
               [], //postBuildCommands
           ),
           DubPackage(
               "bar", //name
               "/path/to/bar/", //path
               "", // mainSourceFile
               "bar", // targetFileName
               [], // dflags
               [], // lflags
               ["/path/to/bar/source/"], // importPaths
               [], // stringImportPaths
               ["/path/to/bar/source/bar.d", "quux.o"], // sourceFiles
               TargetType.staticLibrary,
               ["lefoo", "Have_bar"], // versions
               [], // dependencies
               [], // libs
               true, // active
               [], // preBuildCommands
               [], //postBuildCommands
           ),
       ]
   );

   info.cleanObjectSourceFiles.shouldEqual(DubInfo(
       [
           DubPackage(
               "foo", //name
               "/path/to/", //path
               "/path/to/source/app.d", // mainSourceFile
               "foo", // targetFileName
               [], // dflags
               [], // lflags
               ["/path/to/source/", "/path/to/bar/source/"], // importPaths
               [], // stringImportPaths
               ["/path/to/source/app.d", "baz.o"], // sourceFiles
               TargetType.executable,
               ["lefoo", "Have_foo", "Have_bar"], // versions
               ["bar"], // dependencies
               [], // libs
               true, // active
               [], // preBuildCommands
               [], //postBuildCommands
           ),
           DubPackage(
               "bar", //name
               "/path/to/bar/", //path
               "", // mainSourceFile
               "bar", // targetFileName
               [], // dflags
               [], // lflags
               ["/path/to/bar/source/"], // importPaths
               [], // stringImportPaths
               ["/path/to/bar/source/bar.d", "quux.o"], // sourceFiles
               TargetType.staticLibrary,
               ["lefoo", "Have_bar"], // versions
               [], // dependencies
               [], // libs
               true, // active
               [], // preBuildCommands
               [], //postBuildCommands
           ),
       ]
   ));
}
