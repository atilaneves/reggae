module opt.reggaefile;

import reggae;
enum foo = Target(`foo`, `dmd -of$out $in`, Target(`foo.d`));
enum bar = Target(`bar`, `dmd -of$out $in`, Target(`bar.d`));
mixin build!(foo, optional(bar));
