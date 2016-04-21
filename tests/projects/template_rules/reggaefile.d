module template_rules.reggaefile;

import reggae;
alias objs = objectFiles!(Sources!(), Flags(`-g -O0`));
alias app = link!(ExeName(`app`), objs);
mixin build!app;
