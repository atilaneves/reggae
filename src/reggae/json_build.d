/**
 This module is responsible for the output of a build system
 from a JSON description
 */

module reggae.json_build;


import reggae.build;
import reggae.ctaa;
import reggae.rules.common;
import reggae.options;

import std.json;
import std.algorithm;
import std.array;
import std.conv;
import std.traits;


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


enum JsonDepsFuncName {
    objectFiles,
    staticLibrary,
    targetConcat,
    executable,
}

Build jsonToBuild(in imported!"reggae.options".Options options,
                  in string projectPath,
                  in string jsonString)
{
    return tryJson(jsonString, jsonToBuildImpl(options, projectPath, jsonString));
}

private auto tryJson(E)(in string jsonString, lazy E expr) {
    import core.exception;
    try {
        return expr();
    } catch(JSONException e) {
        rethrow(jsonString, e);
    } catch(RangeError e) {
        import std.stdio;
        stderr.writeln(e.toString);
        rethrow(jsonString, e);
    }

    assert(0);
}

private void rethrow(E)(in string jsonString, E e) {
    throw new Exception("Wrong JSON description for:\n" ~ jsonString ~ "\n" ~ e.msg, e, e.file, e.line);
}

private Build jsonToBuildImpl(in imported!"reggae.options".Options options,
                              in string projectPath,
                              in string jsonString)
{
    import std.exception;

    auto json = parseJSON(jsonString);
    immutable version_ = version_(json);

    enforce(version_ == 0 || version_ == 1, "Unknown JSON build version");

    return version_ == 1
        ? Version1.jsonToBuild(options, projectPath, json)
        : Version0.jsonToBuild(options, projectPath, json);
}

private struct Version0 {

    static Build jsonToBuild(in imported!"reggae.options".Options options,
                             in string projectPath,
                             in JSONValue json)
    {
        import std.typecons: Yes, No;
        Build.TopLevelTarget maybeOptional(in JSONValue json, Target target) {
            immutable optional = ("optional" in json.object) !is null;
            return createTopLevelTarget(target, optional ? Yes.optional : No.optional);
        }

        auto targets = json.array.
            filter!(a => a.object["type"].str != "defaultOptions").
            map!(a => maybeOptional(a, jsonToTarget(options, projectPath, a))).
            array;

        return Build(targets);
    }

    static const(Options) jsonToOptions(const Options options, in JSONValue json) {
        //first, find the JSON object we want
        auto defaultOptionsRange = json.array.filter!(a => a.object["type"].str == "defaultOptions");
        return defaultOptionsRange.empty
            ? options
            : jsonToOptionsImpl(options, defaultOptionsRange.front);
    }
}

private struct Version1 {

    static Build jsonToBuild(in imported!"reggae.options".Options options,
                             in string projectPath,
                             in JSONValue json)
    {
        return Version0.jsonToBuild(options, projectPath, json.object["build"]);
    }

    static const(Options) jsonToOptions(in Options options, in JSONValue json) {
        return jsonToOptionsImpl(options, json.object["defaultOptions"], json.object["dependencies"]);
    }
}

private long version_(in JSONValue json) {
    return json.type == JSONType.object
        ? json.object["version"].integer
        : 0;
}

private Target jsonToTarget(in imported!"reggae.options".Options options,
                            in string projectPath,
                            JSONValue json)
{
    if(json.object["type"].str.to!JsonTargetType == JsonTargetType.dynamic)
        return callTargetFunc(options, projectPath, json);

    auto dependencies = getDeps(options, projectPath, json.object["dependencies"]);
    auto implicits = getDeps(options, projectPath, json.object["implicits"]);

    if(isLeaf(json)) {
        return Target(json.object["outputs"].array.map!(a => a.str).array,
                      "",
                      []);
    }

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
            string[] linkLibraryFlags;
            if (auto p = "link_libraries" in json) {
                linkLibraryFlags = (*p).array.map!(a => a.str).array;
            }
            return Command(CommandType.link,
                           assocList([assocEntry("flags", json.object["flags"].array.map!(a => a.str).array),
                                      assocEntry("link_libraries", linkLibraryFlags)]));
    }
}


private Target[] getDeps(in imported!"reggae.options".Options options,
                         in string projectPath,
                         in JSONValue json)
{
    import core.exception;
    immutable type = json.object["type"].str.to!JsonDependencyType;

    if(type == JsonDependencyType.fixed && "targets" in json.object && json.object["targets"].array.length == 0) {
        return [];
    }
    try {
        return type == JsonDependencyType.fixed
            ? fixedDeps(options, projectPath, json)
            : callDepsFunc(options, projectPath, json);
    } catch(RangeError e) {
        import std.stdio;
        stderr.writeln(e.toString);
        throw new JSONException("Could not get dependencies from JSON object" ~
                                json.to!string);
    } catch(JSONException e) {
        throw new JSONException(e.msg ~ ": object was " ~ json.to!string);
    }
}

private Target[] fixedDeps(in imported!"reggae.options".Options options,
                           in string projectPath,
                           in JSONValue json)
{
    return "targets" in json.object
           ? json.object["targets"].array.map!(a => jsonToTarget(options, projectPath, a)).array
           :  [Target(json.object["outputs"].array.map!(a => a.str.dup.to!string),
                      "",
                      getDeps(options, projectPath, json.object["dependencies"]),
                      getDeps(options, projectPath, json.object["implicits"]))];

}

private Target[] callDepsFunc(in imported!"reggae.options".Options options,
                              in string projectPath,
                              in JSONValue json)
{
    immutable func = json.object["func"].str.to!JsonDepsFuncName;
    final switch(func) {
    case JsonDepsFuncName.objectFiles:
        return objectFiles(options,
                           projectPath,
                           strings(json, "src_dirs"),
                           strings(json, "exclude_dirs"),
                           strings(json, "src_files"),
                           strings(json, "exclude_files"),
                           strings(json, "flags"),
                           strings(json, "includes"),
                           strings(json, "string_imports"));
    case JsonDepsFuncName.staticLibrary:
        return [staticLibrary(options,
                              projectPath,
                              stringVal(json, "name"),
                              strings(json, "src_dirs"),
                              strings(json, "exclude_dirs"),
                              strings(json, "src_files"),
                              strings(json, "exclude_files"),
                              strings(json, "flags"),
                              strings(json, "includes"),
                              strings(json, "string_imports"))];
    case JsonDepsFuncName.executable:
        return [executable(options, projectPath,
                           stringVal(json, "name"),
                           strings(json, "src_dirs"),
                           strings(json, "exclude_dirs"),
                           strings(json, "src_files"),
                           strings(json, "exclude_files"),
                           strings(json, "compiler_flags"),
                           strings(json, "linker_flags"),
                           strings(json, "includes"),
                           strings(json, "string_imports"))];
    case JsonDepsFuncName.targetConcat:
        return json.object["dependencies"].array.
            map!(a => getDeps(options, projectPath, a)).join;
    }
}

private const(string)[] strings(in JSONValue json, in string key) {
    return json.object[key].array.map!(a => a.str).array;
}

private const(string) stringVal(in JSONValue json, in string key) {
    return json.object[key].str;
}


private Target callTargetFunc(in imported!"reggae.options".Options options,
                              in string projectPath,
                              in JSONValue json)
{
    import std.exception;
    import reggae.rules.d;
    import reggae.types;

    enforce(json.object["func"].str == "scriptlike",
            "scriptlike is the only JSON function supported for Targets");

    auto srcFile = SourceFileName(stringVal(json, "src_name"));
    auto app = json.object["exe_name"].isNull
        ? App(srcFile)
        : App(srcFile, BinaryFileName(stringVal(json, "exe_name")));


    return scriptlike(options,
                      projectPath,
                      app,
                      const CompilerFlags(strings(json, "flags")),
                      const ImportPaths(strings(json, "includes")),
                      const StringImportPaths(strings(json, "string_imports")),
                      getDeps(options, projectPath, json["link_with"]));
}


const(Options) jsonToOptions(in Options options, in string jsonString) {
    return tryJson(jsonString, jsonToOptions(options, parseJSON(jsonString)));
}

//get "real" options based on what was passed in via the command line
//and a json object.
//This is needed so that scripting language build descriptions can specify
//default values for the options
//First the command-line parses the options, then the json can override the defaults
const(Options) jsonToOptions(in Options options, in JSONValue json) {
    return version_(json) == 1
        ? Version1.jsonToOptions(options, json)
        : Version0.jsonToOptions(options, json);
}


private const(Options) jsonToOptionsImpl(in Options options,
                                         in JSONValue defaultOptionsObj,
                                         in JSONValue dependencies = parseJSON(`[]`)) {
    import std.exception;
    import std.conv;

    assert(defaultOptionsObj.type == JSONType.object,
           text("jsonToOptions requires an object, not ", defaultOptionsObj.type));

    Options defaultOptions;

    //statically loop over members of Options
    foreach(member; __traits(allMembers, Options)) {

        static if(member[0] != '_') {

            //type alias for the current member
            mixin(`alias T = typeof(defaultOptions.` ~ member ~ `);`);

            //don't bother with functions or with these member variables
            static if(member != "args" && member != "userVars" && !isSomeFunction!T) {
                if(member in defaultOptionsObj) {
                    static if(is(T == bool)) {
                        mixin(`immutable type = defaultOptionsObj.object["` ~ member ~ `"].type;`);
                        if(type == JSONType.true_)
                            mixin("defaultOptions." ~ member ~ ` = true;`);
                        else if(type == JSONType.false_)
                            mixin("defaultOptions." ~ member ~ ` = false;`);
                    }
                    else static if(member == "dflags") {
                        defaultOptions.dflags = defaultOptionsObj.object["dflags"].str.split;
                    }
                    else
                        mixin("defaultOptions." ~ member ~ ` = defaultOptionsObj.object["` ~ member ~ `"].str.to!T;`);
                }
            }
        }
    }

    defaultOptions.dependencies = dependencies.array.map!(a => cast(string)a.str.dup).array;

    return getOptions(defaultOptions, options.args.dup);
}
