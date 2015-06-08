/**
High-level rules for compiling C files
 */

module reggae.rules.c;

import reggae.types;
import reggae.build;
import reggae.rules.common;
import std.algorithm;


/**
 * Compile-time function to that returns a list of Target objects
 * corresponding to C source files from a particular directory
 */
Target[] cObjects(SrcDirs dirs = SrcDirs(),
                  Flags flags = Flags(),
                  ImportPaths includes = ImportPaths(),
                  SrcFiles srcFiles = SrcFiles(),
                  ExcludeFiles excludeFiles = ExcludeFiles())
    () {

    Target[] cCompileInner(in string[] files) {
        return files.map!(a => objectFile(a, flags.value, includes.value)).array;
    }


    return srcObjects!cCompileInner("c", dirs.value, srcFiles.value, excludeFiles.value);
}
