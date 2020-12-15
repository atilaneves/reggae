module project1.reggaefile;
import reggae;
enum mainObj  = Target(`main` ~ objExt,  `dmd -I$project/src -c $in -of$out`, Target(`src/main.d`));
enum mathsObj = Target(`maths` ~ objExt, `dmd -c $in -of$out`, Target(`src/maths.d`));
enum app = Target(`myapp`,
                  `dmd -of$out $in`,
                  [mainObj, mathsObj],
    );
mixin build!(app);
