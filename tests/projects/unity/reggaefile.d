module unity.reggaefile;

import reggae;
alias app = unityBuild!(ExeName(`unity`),
                        Sources!([`src`]),
                        Flags(`-g`));
mixin build!app;
