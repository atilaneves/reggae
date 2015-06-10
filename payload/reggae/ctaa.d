module reggae.ctaa;

/**
An implementation of an associative array useable at compile-time.
Shameless copy of association lists from Lisp.
 */


@safe:


struct AssocList(K, V) {
    import std.algorithm: find;
    import std.array: empty, front;

    AssocEntry!(K, V)[] entries;

    const(V) opIndex(in K key) pure const nothrow {
        auto res = entries.find!(a => a.key == key);
        assert(!res.empty, "AssocList does not contain key " ~ key);
        return res.front.value;
    }

    T get(T)(in K key, T defaultValue) pure const {
        import std.conv: to;
        auto res = entries.find!(a => a.key == key);
        return res.empty ? defaultValue : res.front.value.to!T;
    }
}

struct AssocEntry(K, V) {
    K key;
    V value;
}


AssocEntry!(K, V) assocEntry(K, V)(K key, V value) {
    return AssocEntry!(K, V)(key, value);
}

AssocList!(K, V) assocList(K, V)(AssocEntry!(K, V)[] entries = []) {
    return AssocList!(K, V)(entries);
}
