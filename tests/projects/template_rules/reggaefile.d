module template_rules.reggaefile;

import reggae;
alias objs = objectFiles!(Sources!(), CompilerFlags(`-g -O0`));
alias app = link!(TargetName(`app`), objs);
mixin build!app;
