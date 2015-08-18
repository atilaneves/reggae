module reggae.json_build;


import reggae.build;
import std.json;
import std.algorithm;
import std.array;


Build jsonToBuild(in string jsonString) {
    auto json = parseJSON(jsonString);
    Target[] targets;
    foreach(target; json.array) {
        targets ~= jsonToTarget(target);
    }
    return Build(targets);
}



private Target jsonToTarget(in JSONValue json) {
    if(json.object["dependencies"].array.empty && json.object["implicits"].array.empty)
        return Target(json.object["outputs"].array.map!(a => a.str).array,
                      "",
                      []);

    return Target(json.object["outputs"].array.map!(a => a.str).array,
                  json.object["command"].str,
                  json.object["dependencies"].array.map!(a => jsonToTarget(a)).array,
                  json.object["implicits"].array.map!(a => jsonToTarget(a)).array);
}
