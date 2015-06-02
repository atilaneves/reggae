module reggae.ctaa;

/**
An implementation of an associative array useable at compile-time.
Shameless copy of association lists from Lisp.
 */

import std.algorithm;
import std.range;
import std.conv;

@safe:

struct AssocList {
    AssocEntry[] entries;

    T get(T)(in string key, T defaultValue) pure {
        auto res = entries.find!(a => a.key == key);
        return res.empty ? defaultValue : entries.front.value.to!T;
    }
}


struct AssocEntry {
    string key;
    string value;
}

struct AssocListT(K, V) {
    AssocEntryT!(K, V)[] entries;

    const(V) opIndex(K key) pure const nothrow {
        auto res = entries.find!(a => a.key == key);
        assert(!res.empty, "AssocList does not contain key " ~ key);
        return res.front.value;
    }

}

struct AssocEntryT(K, V) {
    K key;
    V value;
}


AssocEntryT!(K, V) assocEntry(K, V)(K key, V value) {
    return AssocEntryT!(K, V)(key, value);
}

AssocListT!(K, V) assocList(K, V)(AssocEntryT!(K, V)[] entries) {
    return AssocListT!(K, V)(entries);
}
