module reggae.dub_json;

import reggae.dub;
import reggae.build;
import stdx.data.json;
import std.algorithm: map, filter;


DubInfo getDubInfo(string jsonString) @safe {
    auto json = parseJSONValue(jsonString);
    auto packages = json.byKey("packages").get!(JSONValue[]);
    return DubInfo(packages.map!(a => DubPackage(a.byKey("name").get!string,
                                                 a.byKey("path").get!string,
                                                 a.getOptional("mainSourceFile"),
                                                 a.getOptional("targetFileName"),
                                                 a.byKey("dflags").jsonValueToStrings,
                                                 a.byKey("importPaths").jsonValueToStrings,
                                                 a.byKey("stringImportPaths").jsonValueToStrings,
                                                 a.byKey("files").jsonValueToFiles,
                                                 a.getOptional("targetType"),
                                                 a.getOptionalList("versions"),
                                                 a.getOptionalList("dependencies"),
                                                 a.getOptionalList("libs"))).array);
}


private string[] jsonValueToFiles(JSONValue files) @safe {
    return files.get!(JSONValue[]).
        filter!(a => a.byKey("type") == "source").
        filter!(a => a.byOptionalKey("active", true)). //true for backward compatibility
        map!(a => a.byKey("path").get!string).
        array;
}

private string[] jsonValueToStrings(JSONValue json) @safe {
    return json.get!(JSONValue[]).map!(a => a.get!string).array;
}


private auto byKey(JSONValue json, in string key) @safe {
    return json.get!(JSONValue[string])[key];
}

private auto byOptionalKey(T)(JSONValue json, in string key, T def) {
    auto value = json.get!(JSONValue[string]);
    return key in value ? value[key].get!T : def;
}


private string getOptional(JSONValue json, in string key) @safe {
    auto aa = json.get!(JSONValue[string]);
    return key in aa ? aa[key].get!string : "";
}

private string[] getOptionalList(JSONValue json, in string key) @safe {
    auto aa = json.get!(JSONValue[string]);
    return key in aa ? aa[key].jsonValueToStrings : [];
}
