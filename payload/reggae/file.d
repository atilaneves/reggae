module reggae.file;

import std.file: timeLastModified;

@safe:

bool newerThan(in string a, in string b) {
    import std.file: exists, timeLastModified;

    if(!a.exists || !b.exists)
        return true;

    return a.timeLastModified > b.timeLastModified;
}
