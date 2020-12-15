module project2.reggaefile;
import reggae;
enum mainObj  = Target(`main` ~ objExt, `dmd -I$project -c $in -of$out`, Target(`source/main.d`));
enum fooObj   = Target(`foo` ~ objExt,  `dmd -c $in -of$out`, Target(`source/foo.d`));
enum app = Target(`appp`,
                  `dmd -of$out $in`,
                  [mainObj, fooObj],
    );
mixin build!(app);
