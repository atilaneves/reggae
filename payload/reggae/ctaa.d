module reggae.ctaa;


import std.algorithm;
import std.range;
import std.conv;


struct AssocList {
    AssocEntry[] entries;

    T get(T)(in string key, T defaultValue) @safe pure {
        auto res = entries.find!(a => a.key == key);
        return res.empty ? defaultValue : entries.front.value.to!T;
    }
}


struct AssocEntry {
    string key;
    string value;
}
