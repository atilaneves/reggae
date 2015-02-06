module reggae.reflect;


import reggae.build;
import std.traits;
import std.conv;
import std.array: empty;


const(Build) getBuild(alias Module)() if(is(typeof(Module)) && isSomeString!(typeof(Module))) {
    mixin("import " ~ Module ~ ";");
    return getBuild!(mixin(Module));
}

const(Build) getBuild(alias Module)() if(!is(typeof(Module))) {
    mixin("import " ~ fullyQualifiedName!Module ~ ";");
    const(Build)[] builds;
    foreach(moduleMember; __traits(allMembers, Module)) {
        static if(is(typeof(mixin(moduleMember)))) {
            alias type = typeof(mixin(moduleMember));
            static if(is(Unqual!type == Build)) {
                builds ~= mixin(moduleMember);
            }
        }
    }


    assert(!builds.empty, "Could not find a public Build object in " ~ fullyQualifiedName!Module);
    assert(builds.length == 1, text("Only one build object allowed per module, ",
                                    fullyQualifiedName!Module, " has ", builds.length));

    return builds[0];
}
