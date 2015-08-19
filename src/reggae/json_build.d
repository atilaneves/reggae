module reggae.json_build;


import reggae.build;
import reggae.ctaa;
import reggae.rules.common;

import std.json;
import std.algorithm;
import std.array;
import std.conv;

enum JsonCommandType {
    shell,
    link,
}

enum JsonDependencyType {
    fixed,
    dynamic,
}

enum JsonFuncName {
    objectFiles,
}


Build jsonToBuild(in string projectPath, in string jsonString) {
    auto json = parseJSON(jsonString);
    Target[] targets;
    foreach(target; json.array) {
        targets ~= jsonToTarget(projectPath, target);
    }
    return Build(targets);
}



private Target jsonToTarget(in string projectPath, in JSONValue json) {
    immutable depsType = json.object["dependencies"].object["type"].str.to!JsonDependencyType;
    immutable impsType = json.object["implicits"].object["type"].str.to!JsonDependencyType;

    const dependencies = depsType == JsonDependencyType.fixed
        ? json.object["dependencies"].object["targets"].array.map!(a => jsonToTarget(projectPath, a)).array
        : callDepsFunc(projectPath, json.object["dependencies"]);

    const implicits = impsType == JsonDependencyType.fixed
        ? json.object["implicits"].object["targets"].array.map!(a => jsonToTarget(projectPath, a)).array
        : callDepsFunc(projectPath, json.object["implicits"]);

    if(isLeaf(json))
        return Target(json.object["outputs"].array.map!(a => a.str).array,
                      "",
                      []);

    return Target(json.object["outputs"].array.map!(a => a.str).array,
                  jsonToCommand(json.object["command"]),
                  dependencies,
                  implicits);
}

private bool isLeaf(in JSONValue json) pure {
    return json.object["dependencies"].object["type"].str.to!JsonDependencyType == JsonDependencyType.fixed &&
        json.object["dependencies"].object["targets"].array.empty &&
        json.object["implicits"].object["type"].str.to!JsonDependencyType == JsonDependencyType.fixed &&
        json.object["implicits"].object["targets"].array.empty;
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


private Target[] callDepsFunc(in string projectPath, in JSONValue json) {
    immutable func = json.object["func"].str.to!JsonFuncName;
    final switch(func) {
    case JsonFuncName.objectFiles:
        return objectFiles(projectPath,
                           json.object["src_dirs"].array.map!(a => a.str).array,
                           json.object["exclude_dirs"].array.map!(a => a.str).array,
                           json.object["src_files"].array.map!(a => a.str).array,
                           json.object["exclude_files"].array.map!(a => a.str).array,
                           json.object["flags"].str,
                           json.object["includes"].array.map!(a => a.str).array,
                           json.object["string_imports"].array.map!(a => a.str).array);

    }
}
