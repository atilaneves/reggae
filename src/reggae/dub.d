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
    string[] files;
}


DubInfo dubInfo(string jsonString) @safe {
    auto json = parseJSONValue(jsonString);
    auto packages = json.byKey("packages").get!(JSONValue[]);
    return DubInfo(packages.map!(a => DubPackage(a.byKey("name").get!string,
                                                 a.byKey("path").get!string,
                                                 a.byKey("files").get!(JSONValue[]).jsonValueToFiles)).array);
}


private string[] jsonValueToFiles(JSONValue[] files) @safe {
    return files.map!(a => a.byKey("path").get!string).array;
}


auto byKey(JSONValue json, in string key) @safe {
    return json.get!(JSONValue[string])[key];
}


Target[] dubInfoToTargets(in DubInfo info) {
    Target[] targets;

    foreach(const pack; info.packages) {
        foreach(const file; pack.files) {
            targets ~= dCompile(buildPath(pack.path, file));
        }
    }

    return targets;
}
