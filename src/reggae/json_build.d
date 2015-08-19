module reggae.json_build;


import reggae.build;
import reggae.ctaa;
import reggae.rules.common;

import std.json;
import std.algorithm;
import std.array;
import std.conv;

enum JsonTargetType {
    fixed,
    dynamic,
}

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
    staticLibrary,
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
    if(json.object["type"].str.to!JsonTargetType == JsonTargetType.dynamic)
        return callTargetFunc(projectPath, json);

    immutable depsType = json.object["dependencies"].object["type"].str.to!JsonDependencyType;
    const dependencies = depsType == JsonDependencyType.fixed
        ? json.object["dependencies"].object["targets"].array.map!(a => jsonToTarget(projectPath, a)).array
        : callDepsFunc(projectPath, json.object["dependencies"]);

    immutable impsType = json.object["implicits"].object["type"].str.to!JsonDependencyType;
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
                           strings(json, "src_dirs"),
                           strings(json, "exclude_dirs"),
                           strings(json, "src_files"),
                           strings(json, "exclude_files"),
                           stringVal(json, "flags"),
                           strings(json, "includes"),
                           strings(json, "string_imports"));
    case JsonFuncName.staticLibrary:
        return staticLibrary(projectPath,
                             stringVal(json, "name"),
                             strings(json, "src_dirs"),
                             strings(json, "exclude_dirs"),
                             strings(json, "src_files"),
                             strings(json, "exclude_files"),
                             stringVal(json, "flags"),
                             strings(json, "includes"),
                             strings(json, "string_imports"));

    }
}

private const(string)[] strings(in JSONValue json, in string key) {
    return json.object[key].array.map!(a => a.str).array;
}

private const(string) stringVal(in JSONValue json, in string key) {
    return json.object[key].str;
}


private Target callTargetFunc(in string projectPath, in JSONValue json) {
    import std.exception;
    import reggae.rules.d;
    import reggae.types;

    enforce(json.object["func"].str == "scriptlike", "Only scriptlike is supported for Targets");

    return scriptlike(projectPath,
                      App(SourceFileName(stringVal(json, "src_name")),
                          BinaryFileName(stringVal(json, "exe_name"))),
                      Flags(stringVal(json, "flags")),
                      const ImportPaths(strings(json, "includes")),
                      const StringImportPaths(strings(json, "string_imports")),
                      []);
}
