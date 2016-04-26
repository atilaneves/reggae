version(unittest) import unit_threaded;

int mul(int i, int j) { return i * j; }

unittest { mul(2, 3).shouldEqual(6); }
