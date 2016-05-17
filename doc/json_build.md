JSON build descriptions
=======================

This document describes the JSON protocol that enables build
descriptions to be written in languages other than D, the
language that reggae is written in. Any language may be
used to produce the JSON output, as long as the reggae
binary is modified in order to know how to invoke the
interpreter, which must write the JSON description to
standard output. The program/script must also understand
the command-line option `--options`, which is a JSON
object with all configured reggae options. In this way
the build description can access user-defined variables,
what compiler was selected and so forth.

Version 0 of the protocol was a JSON array of top-level
targets. Each target is a JSON object with a field called
"type" with two possible string values: "fixed" or
"dynamic".

Fixed targets do not depend on the contents of the file
system and cannot vary at run-time. Dynamic targets are
the exact opposite and will generally depend on which files
are in a particular directory/folder.

Other that a type, targets must have a string array called "outputs"
with the result of running the command, and special fields named
"dependencies" and "implicits". Each one of these is another Target
JSON object, but this time with a type (same as above) and a field
named "targets" with an array of Target objects identical in schema to
the top-level targets.

Fixed targets must have a field name "command" with the shell command
to execute to produce them. Dynamic targets must have a field called
"func" with the function to be called to produce them. This is
effectively an RPC into the D code to examine the file system.
Dynamic targets must also supply parameters for this RPC call.
Exactly which parameters depends on the function in question.

As version 0 used an array as its top-level JSON construct, it was
extended with a special target type called "defaultOptions" that
allowed the foreign language to set default values for the
Options struct. There was also no way to communicate back to reggae
which files are dependencies of the build description if it spans
multiple files. In Python, this would be every file transitively
imported by `reggaefile.py`. Version 1 corrects that oversight.

Version 1 is similar to version 0 but changes the JSON to be an
object instead of an array. Version 0 is included inside in the
"build" field, which is the array returned by version 0. An
example of a version 1 JSON build:

```javascript
{
    "version": 1,
    "build": [ ... ],
    "defaultOptions": {"cCompiler": "weirdcc"},
    "dependencies": ["/path/to/foo.py", "/path/to/bar.py"]
}
```

It should be self-explanatory.
