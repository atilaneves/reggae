module phony_proj.reggaefile;

import reggae;

alias app = scriptlike!(App(SourceFileName("main.d"), BinaryFileName("app")));
alias doit = phony!("doit", "./app", app);

mixin build!(app, optional!(doit));
