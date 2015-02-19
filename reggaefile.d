import reggae;

mixin dExe!(App("src/reggae/reggae_main.d", "reggae"),
            Flags("-g -debug"),
            ImportPaths(["src"]),
            StringImportPaths(["src/reggae"]));
