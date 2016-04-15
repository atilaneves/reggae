module project2.reggaefile;
import reggae;
enum mainObj  = Target(`main.o`, `dmd -I$project -c $in -of$out`, Target(`source/main.d`));
enum fooObj   = Target(`foo.o`,  `dmd -c $in -of$out`, Target(`source/foo.d`));
enum app = Target(`appp`,
                  `dmd -of$out $in`,
                  [mainObj, fooObj],
    );
mixin build!(app);
