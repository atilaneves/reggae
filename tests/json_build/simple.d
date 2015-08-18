module tests.json_build.simple;


import reggae;
import reggae.json_build;
import unit_threaded;




immutable fooObjJson = `
[
  {
    "outputs": ["foo.o"],
    "command": "dmd -of$out -c $in",
    "dependencies": [{"outputs": ["foo.d"], "command": "", "dependencies": [], "implicits": []}],
    "implicits": []
  }
]`;

void testFooObj() {
    jsonToBuild(fooObjJson).shouldEqual(
        Build(Target("foo.o", "dmd -of$out -c $in", Target("foo.d"))));
}
