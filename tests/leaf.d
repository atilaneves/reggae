module tests.leaf;

import unit_threaded;
import reggae;


void testLeaf() {
    leaf("myleaf.txt").shouldEqual(Target("myleaf.txt", null, null));
}
