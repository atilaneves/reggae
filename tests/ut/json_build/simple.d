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

@("Foo object") unittest {
    import reggae.config: options;
    jsonToBuild(options, "", fooObjJson).shouldEqual(
        Build(Target("foo.o", "dmd -of$out -c $in", Target("foo.d"))));
}


immutable optionalJson = `
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
  },
  {
    "type": "fixed",
    "outputs": ["bar.o"],
    "command": {"type": "shell", "cmd": "dmd -of$out -c $in"},
    "dependencies": {
        "type": "fixed",
        "targets": [
            {"type": "fixed",
             "outputs": ["bar.d"],
             "command": {},
             "dependencies": {"type": "fixed", "targets": []},
             "implicits": {"type": "fixed", "targets": []}}]},
    "implicits": {"type": "fixed", "targets": []},
    "optional": true
  }
]
`;

@("Optional target")
unittest {
    import reggae.config: options;
    jsonToBuild(options, "", optionalJson).shouldEqual(
        Build(Target("foo.o", "dmd -of$out -c $in", Target("foo.d")),
              optional(Target("bar.o", "dmd -of$out -c $in", Target("bar.d")))));
}

immutable fooObjJson2 = `
{
    "version": 1,
    "defaultOptions": {},
    "dependencies": [],
    "build": [
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
  ]
}
`;


@("version2")
unittest {
    import reggae.config: options;
    jsonToBuild(options, "", fooObjJson2).shouldEqual(
        Build(Target("foo.o", "dmd -of$out -c $in", Target("foo.d"))));
}
