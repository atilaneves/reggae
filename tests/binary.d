module tests.binary;

import reggae;
import unit_threaded;


void testDep() {
    immutable depFileLines = [
        "objs/calc.objs/src/cpp/maths.o: \\",
        "/home/aalvesne/coding/d/reggae/tmp/aruba/mixproj/src/cpp/maths.cpp \\",
        "/home/aalvesne/coding/d/reggae/tmp/aruba/mixproj/headers/maths.hpp\n"];
    dependenciesFromFile(depFileLines).shouldEqual(
        [ "/home/aalvesne/coding/d/reggae/tmp/aruba/mixproj/src/cpp/maths.cpp",
          "/home/aalvesne/coding/d/reggae/tmp/aruba/mixproj/headers/maths.hpp"]);
}
