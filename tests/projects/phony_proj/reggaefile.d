module phony_proj.reggaefile;

import reggae;
import reggae.path: buildPath;

alias app = scriptlike!(App(SourceFileName("src/main.d"), BinaryFileName("app" ~ exeExt)));
alias doit = phony!("doit", buildPath("./app"), app);

mixin build!(app, optional!(doit));
