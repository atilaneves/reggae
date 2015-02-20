module reggae.dub;

import reggae.build;
import reggae.rules;
import stdx.data.json;
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


DubInfo dubInfo(string jsonString) @safe {
    auto json = parseJSONValue(jsonString);
    auto packages = json.byKey("packages").get!(JSONValue[]);
    return DubInfo(packages.map!(a => DubPackage(a.byKey("name").get!string,
                                                 a.byKey("path").get!string,
                                                 a.byKey("dflags").jsonValueToStrings,
                                                 a.byKey("importPaths").jsonValueToStrings,
                                                 a.byKey("stringImportPaths").jsonValueToStrings,
                                                 a.byKey("files").jsonValueToFiles)).array);
}


private string[] jsonValueToFiles(JSONValue files) @safe {
    return files.get!(JSONValue[]).map!(a => a.byKey("path").get!string).array;
}

private string[] jsonValueToStrings(JSONValue json) @safe {
    return json.get!(JSONValue[]).map!(a => a.get!string).array;
}


private auto byKey(JSONValue json, in string key) @safe {
    return json.get!(JSONValue[string])[key];
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

Target[] dubTargets(in string jsonString) @safe {
    return dubInfoToTargets(dubInfo(jsonString));
}
