module scriptlike.reggaefile;

import reggae;
import reggae.path: buildPath;

alias cppSrcs = Sources!(Dirs([`cpp`]),
                         Files([`extra/constants.cpp`]),
                         Filter!(a => a != buildPath(`cpp/extra_main.cpp`)));
alias cppObjs = objectFiles!(cppSrcs, Flags(`-pg`));

alias app = reggae.scriptlike!(App(SourceFileName(`d/main.d`), BinaryFileName(`calc`)),
                               Flags(`-debug -O`),
                               ImportPaths([`d`]),
                               StringImportPaths([`resources/text`]),
                               cppObjs,
    );
mixin build!(app);
