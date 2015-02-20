module reggae.dub;
import stdx.data.json;
import std.algorithm: map;
import std.array: array;

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
    auto packages = json.get!(JSONValue[string])["packages"].get!(JSONValue[]);
    return DubInfo(packages.map!(a => DubPackage(a.get!(JSONValue[string])["name"].get!string,
                                                 a.get!(JSONValue[string])["path"].get!string,
                                                 a.get!(JSONValue[string])["files"].get!(JSONValue[]).jsonValueToFiles)).array);
}


private string[] jsonValueToFiles(JSONValue[] files) @safe {
    return files.map!(a => a.get!(JSONValue[string])["path"].get!string).array;
}
