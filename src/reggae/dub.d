module reggae.dub;

struct DubInfo {
    DubPackage[] packages;
}

struct DubPackage {
    string name;
    string path;
    string[] files;
}

DubInfo dubInfo(string jsonString) @safe pure nothrow {
    return DubInfo();
}
