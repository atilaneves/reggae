module unity.reggaefile;

import reggae;
alias app = unityBuild!(ExeName(`unity`),
                        Sources!([`src`]),
                        CompilerFlags(`-g`));
mixin build!app;
