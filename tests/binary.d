module tests.binary;

import reggae;
import unit_threaded;


void testDep() {
    immutable depFileString = "objs/calc.objs/src/cpp/maths.o: \\\n
 /home/aalvesne/coding/d/reggae/tmp/aruba/mixproj/src/cpp/maths.cpp \\\n
 /home/aalvesne/coding/d/reggae/tmp/aruba/mixproj/headers/maths.hpp\n";
    dependenciesFromFile(depFileString).shouldEqual(
        [ "/home/aalvesne/coding/d/reggae/tmp/aruba/mixproj/src/cpp/maths.cpp",
          "/home/aalvesne/coding/d/reggae/tmp/aruba/mixproj/headers/maths.hpp"]);
}
