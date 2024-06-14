module unity.reggaefile;

import reggae;
alias app = unityBuild!(TargetName(`unity`),
                        Sources!([`src`]),
                        CompilerFlags(`-g`));
mixin build!app;
