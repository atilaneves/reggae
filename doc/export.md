Exporting Builds
================

To avoid making other developers have to install reggae in order
to build your software, it is possible to export the build description
to the backends that reggae supports.

Using the `--export` option from the root directory of your project will
result in the creation of build systems for GNU make, ninja and tup
that anybody else can run.
