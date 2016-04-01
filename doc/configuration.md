Run-time Configuration
======================

## Access to command-line parameters

The command-line options passed to reggae are available to D build descriptions
in `reggae.config.options`, a struct of [`Options`](../payload/reggae/options.d) type.
It is not currently available to build descriptions in other languages.

## Default Options

Some builds may always use the same command-line options, as is the
case when using a special compiler for embedded development. Since it
is tedious and error-prone to require users to always specify these
options, it is possible to override defaults for a build in
particular.  In this case, default options can be used that can still
be overridden from the command-line. To do that:

### D

```d
import reggae;
defaultOptions.cCompiler =  "weirdcc"; // for instance
```

### Python

```python
# the name of the variable doesn't matter
opts = DefaultOptions(cCompiler="weirdcc")
```

### Ruby

Not implemented yet.

### Javascript

Not implemented yet.

### Lua

Not implemented yet.


All of the variables in the `Options` struct can be set this way.


## User-defined Variables

To enable/disable features at build configuration time, users may
define their own variables on the command-line when running
reggae. These variables and their values will then be available in the
build description. The only type allowed is string, and the user
variables are represented as an associative array / dict / hash /
object / table of string to string in the respective languages.
In D however, using the `get` member function with a default
value will convert the string into the type of the supplied
default. Please see the example below.

To define a variable, use the `-d var=value` when calling the
reggae executable. Multiple variables may be defined at once.

To access the variables and their values programatically:

### D
```d
static if(userVars.get("enableTests", true)) {
    mixin build!(ut, app);
}

static if(userVars.get("number", 3) == 5) {
   // ...
}
```

`userVars` can also be subscripted, but that will throw
an exception if not set. It's usually better to use `get`.


### Python

```python
if user_vars.get("enableTests", "true") == "true":
   bld = Build(ut, app)
```

### Ruby

Not implemented yet.

### Javascript

Not implemented yet.

### Lua

Not implemented yet.
