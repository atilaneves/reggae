module reggae.ctaa;


import std.algorithm;
import std.range;
import std.conv;


struct AssocList {
    AssocEntry[] entries;

    T get(T)(in string key, T defaultValue) {
        auto res = entries.find!(a => a.key == key);
        return entries.empty ? defaultValue : entries.front.value.to!T;
    }

    ref string opIndex(in string key) @safe pure nothrow {
        auto res = entries.find!(a => a.key == key);
        if(!res.empty) return res.front.value;

        entries ~= AssocEntry(key);
        return entries[$ - 1].value;
    }
}


struct AssocEntry {
    string key;
    string value;
}
