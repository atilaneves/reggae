module reggae.dub;

import reggae.build;
import reggae.rules;
import std.algorithm: map;
import std.array: array;
import std.path: buildPath;


struct DubInfo {
    DubPackage[] packages;
}


struct DubPackage {
    string name;
    string path;
    string[] flags;
    string[] importPaths;
    string[] stringImportPaths;
    string[] files;
}

Target[] dubInfoToTargets(in DubInfo info) @safe pure {
    Target[] targets;

    foreach(const pack; info.packages) {
        foreach(const file; pack.files) {
            targets ~= dCompile(buildPath(pack.path, file),
                                pack.flags.join(" "),
                                pack.importPaths,
                                pack.stringImportPaths,
                                pack.path);
        }
    }

    return targets;
}
