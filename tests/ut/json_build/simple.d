module tests.ut.json_build.simple;


import reggae;
import reggae.json_build;
import unit_threaded;


immutable fooObjJson = `
[
  {
    "type": "fixed",
    "outputs": ["foo.o"],
    "command": {"type": "shell", "cmd": "dmd -of$out -c $in"},
    "dependencies": {
        "type": "fixed",
        "targets": [
            {"type": "fixed",
             "outputs": ["foo.d"],
             "command": {},
             "dependencies": {"type": "fixed", "targets": []},
             "implicits": {"type": "fixed", "targets": []}}]},
    "implicits": {"type": "fixed", "targets": []}
  }
]`;

void testFooObj() {
    jsonToBuild("", fooObjJson).shouldEqual(
        Build(Target("foo.o", "dmd -of$out -c $in", Target("foo.d"))));
}
