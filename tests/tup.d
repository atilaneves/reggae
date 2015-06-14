module tests.tup;


import unit_threaded;
import reggae;


void testEmpty() {
    const tup = Tup();
    tup.output.shouldEqual("");
    tup.fileName.shouldEqual("Tupfile");
}


void testSimpleDBuild() {
    const mainObj  = Target(`main.o`,  `dmd -I$project/src -c $in -of$out`, Target(`src/main.d`));
    const mathsObj = Target(`maths.o`, `dmd -c $in -of$out`, Target(`src/maths.d`));
    const app = Target(`myapp`,
                       `dmd -of$out $in`,
                       [mainObj, mathsObj]
        );
    const build = Build(app);
    const tup = Tup(build, "/path/to/project");

    tup.lines.shouldEqual(
        [": /path/to/project/src/main.d |> dmd -I/path/to/project/src -c /path/to/project/src/main.d -ofobjs/myapp.objs/main.o |> objs/myapp.objs/main.o",
         ": /path/to/project/src/maths.d |> dmd -c /path/to/project/src/maths.d -ofobjs/myapp.objs/maths.o |> objs/myapp.objs/maths.o",
         ": objs/myapp.objs/main.o objs/myapp.objs/maths.o |> dmd -ofmyapp objs/myapp.objs/main.o objs/myapp.objs/maths.o |> myapp"
                              ]);
}
