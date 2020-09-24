module reggae.dub.json;

import reggae.dub.info;
import reggae.build;
import std.json;
import std.algorithm: map, filter;


DubInfo jsonStringToDubInfo(in string origString) @trusted {

    import std.string: indexOf;
    import std.array;
    import std.range: iota;
    import core.exception: RangeError;
    import std.conv: text;
    import std.exception: enforce;

    string nextOpenCurly(string str) {
        return str[str.indexOf("{") .. $];
    }

    try {

        // the output might contain non-JSON at the beginning in stderr
        auto jsonString = nextOpenCurly(origString);

        for(; ; jsonString = nextOpenCurly(jsonString[1..$])) {
            auto json = parseJSON(jsonString);

            bool hasKey(in string key) {
                try
                    return (key in json.object) !is null;
                catch(JSONException ex)
                    return false;
            }

            if(!hasKey("packages") || !hasKey("targets")) {
                continue;
            }

            auto packages = json.byKey("packages").array;
            auto targets = json.byKey("targets").array;

            // gets the package from `packages` corresponding to target `i`
            auto packageForTarget(JSONValue target) {
                import std.algorithm: find;
                return packages.find!(a => a["name"] == target.object["rootPackage"]).front;
            }

            // unfortunately there's a hybrid approach going on here.
            // dub seems to put most of the important information in `targets`
            // but unfortunately under that `sourceFiles` contains object files
            // from every package.
            // So we take our information from targets mostly, except for the
            // source files
            auto info = DubInfo(targets
                                .map!((target) {

                                    auto dubPackage = packageForTarget(target);
                                    auto bs = target.object["buildSettings"];

                                    return DubPackage(
                                        bs.byKey("targetName").str,
                                        dubPackage.byKey("path").str,
                                        bs.getOptional("mainSourceFile"),
                                        bs.getOptional("targetName"),
                                        bs.byKey("dflags").jsonValueToStrings,
                                        bs.byKey("lflags").jsonValueToStrings,
                                        bs.byKey("importPaths").jsonValueToStrings,
                                        bs.byKey("stringImportPaths").jsonValueToStrings,
                                        bs.byKey("sourceFiles").jsonValueToStrings,
                                        bs.getOptionalEnum!TargetType("targetType"),
                                        bs.getOptionalList("versions"),
                                        target.getOptionalList("dependencies"),
                                        bs.getOptionalList("libs"),
                                        true, // backwards compatibility (active)
                                        bs.getOptionalList("preBuildCommands"),
                                        bs.getOptionalList("postBuildCommands"),
                                    );
                                })
                                .filter!(a => a.active)
                                .array);
            info = info.cleanObjectSourceFiles;

            // in dub.json/dub.sdl, $PACKAGE_DIR is a variable that refers to the root
            // of the dub package
            void resolvePackageDir(in DubPackage dubPackage, ref string str) {
                str = str.replace("$PACKAGE_DIR", dubPackage.path);
            }

            foreach(ref dubPackage; info.packages) {
                foreach(ref member; dubPackage.tupleof) {

                    static if(is(typeof(member) == string)) {
                        resolvePackageDir(dubPackage, member);
                    } else static if(is(typeof(member) == string[])) {
                        foreach(ref elt; member)
                            resolvePackageDir(dubPackage, elt);
                    }
                }
            }

            enforce(info.packages.length > 0,
                    text("Parsing dub describe JSON yielded 0 dub packages"));

            return info;
        }
    } catch(RangeError e) {
        import std.stdio;
        stderr.writeln("Could not parse the output of dub describe:\n", origString);
        throw e;
    }
}


private string[] jsonValueToFiles(JSONValue files) @trusted {
    import std.array;

    return files.array.
        filter!(a => ("type" in a && a.byKey("type").str == "source") ||
                     ("role" in a && a.byKey("role").str == "source") ||
                     ("type" !in a && "role" !in a)).
        map!(a => a.byKey("path").str).
        array;
}

private string[] jsonValueToStrings(JSONValue json) @trusted {
    import std.array;
    return json.array.map!(a => a.str).array;
}


private JSONValue byKey(JSONValue json, in string key) @trusted {
    import core.exception: RangeError;
    try
        return json.object[key];
    catch(RangeError e) {
        throw new Exception("Could not find key " ~ key);
    }
}

private bool byOptionalKey(JSONValue json, in string key, bool def) {
    import std.conv: to;
    auto value = json.object;
    return key in value ? value[key].boolean : def;
}

//std.json has no conversion to bool
private bool boolean(JSONValue json) @trusted {
    import std.exception: enforce;
    enforce!JSONException(json.type == JSONType.true_ || json.type == JSONType.false_,
                          "JSONValue is not a boolean");
    return json.type == JSONType.true_;
}

private string getOptional(JSONValue json, in string key) @trusted {
    auto aa = json.object;
    return key in aa ? aa[key].str : "";
}

private T getOptionalEnum(T)(JSONValue json, in string key) @trusted {
    auto aa = json.object;
    return key in aa ? cast(T)aa[key].integer : T.init;
}

private string[] getOptionalList(JSONValue json, in string key) @trusted {
    auto aa = json.object;
    return key in aa ? aa[key].jsonValueToStrings : [];
}

// dub describe, due to a bug, ends up including object files listed as sources
// in a dependent package in the `sourceFiles` part of `target.buildSettings`
// for the main package. We clean it up here.
DubInfo cleanObjectSourceFiles(in DubInfo info) {
    import std.algorithm: find, uniq, joiner, canFind, remove;
    import std.array: array;

    auto ret = info.dup;

    bool isObjectFile(in string fileName) {
        import std.path: extension;
        return fileName.extension == ".o";
    }

    auto sourceObjectFiles = info.packages
        .map!(a => a.files.dup)
        .joiner
        .filter!isObjectFile
        .uniq;

    foreach(sourceObjectFile; sourceObjectFiles) {
        const packagesWithFile = ret.packages.filter!(a => a.files.canFind(sourceObjectFile)).array;
        foreach(ref dubPackage; ret.packages) {
            // all but the last package get scrubbed
            if(dubPackage.files.canFind(sourceObjectFile) && dubPackage != packagesWithFile[$-1]) {
                dubPackage.files = dubPackage.files.filter!(a => a != sourceObjectFile).array;
            }
        }
    }

    return ret;
}
