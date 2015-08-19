module reggae.json_build;


import reggae.build;
import reggae.ctaa;

import std.json;
import std.algorithm;
import std.array;
import std.conv;


Build jsonToBuild(in string jsonString) {
    auto json = parseJSON(jsonString);
    Target[] targets;
    foreach(target; json.array) {
        targets ~= jsonToTarget(target);
    }
    return Build(targets);
}



private Target jsonToTarget(in JSONValue json) pure {
    immutable depsType = json.object["dependencies"].object["type"].str.to!JsonDependencyType;
    immutable impsType = json.object["implicits"].object["type"].str.to!JsonDependencyType;

    if(depsType != JsonDependencyType.fixed || impsType != JsonDependencyType.fixed)
        throw new Exception("Only fixed");


    if(isLeaf(json))
        return Target(json.object["outputs"].array.map!(a => a.str).array,
                      "",
                      []);

    return Target(json.object["outputs"].array.map!(a => a.str).array,
                  jsonToCommand(json.object["command"]),
                  json.object["dependencies"].object["targets"].array.map!(a => jsonToTarget(a)).array,
                  json.object["implicits"].object["targets"].array.map!(a => jsonToTarget(a)).array);
}

private bool isLeaf(in JSONValue json) pure {
    return json.object["dependencies"].object["targets"].array.empty &&
        json.object["implicits"].object["targets"].array.empty;
}

enum JsonCommandType {
    shell,
    link,
}

enum JsonDependencyType {
    fixed,
}

private Command jsonToCommand(in JSONValue json) pure {
    immutable type = json.object["type"].str.to!JsonCommandType;
    final switch(type) with(JsonCommandType) {
        case shell:
            return Command(json.object["cmd"].str);
        case link:
            return Command(CommandType.link,
                           assocList([assocEntry("flags", json.object["flags"].str.splitter.array)]));
    }
}
