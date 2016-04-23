module scriptlike.reggaefile;

import reggae;

alias cppSrcs = Sources!(Dirs([`cpp`]),
                         Files([`extra/constants.cpp`]),
                         Filter!(a => a != `cpp/extra_main.cpp`));
alias cppObjs = objectFiles!(cppSrcs, Flags(`-pg`));

alias app = reggae.scriptlike!(App(SourceFileName(`d/main.d`), BinaryFileName(`calc`)),
                               Flags(`-debug -O`),
                               ImportPaths([`d`]),
                               StringImportPaths([`resources/text`]),
                               cppObjs,
    );
mixin build!(app);
