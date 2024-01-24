module reggae.rules.dub;

public import reggae.rules.dub.runtime;
public import reggae.rules.dub.compile;
public import reggae.rules.dub.external;

// for some reason DCD don't work for this?
import reggae.dub.info: DubInfo;

enum CompilationMode {
    options,  /// whatever the command-line option was
    module_,  /// compile per module
    package_, /// compile per package
    all,      /// compile all source files
}

package template oneOptionalOf(T, A...) {
    import std.meta: Filter;

    alias ofType = Filter!(isOfType!T, A);
    static assert(ofType.length == 0 || ofType.length == 1,
                  "Only 0 or one of `" ~ T.stringof ~ "` allowed");

    static if(ofType.length == 0)
        enum oneOptionalOf = T();
    else
        enum oneOptionalOf = ofType[0];
}

package template isOfType(T) {
    enum isOfType(alias A) = is(typeof(A) == T);
}
