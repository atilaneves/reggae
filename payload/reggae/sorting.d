module reggae.sorting;

import std.range: zip;
import std.path: pathSplitter;
import std.array: array;

@safe:

bool isInSamePackageAs(in string path1, in string path2) pure nothrow {
    const pathParts1 = path1.pathSplitter.array[0.. $ - 2];
    const pathParts2 = path2.pathSplitter.array[0.. $ - 2];
    return pathParts1 == pathParts2;
}
