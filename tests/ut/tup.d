module tests.ut.tup;


import unit_threaded;
import reggae;
import reggae.backend.tup;
import reggae.path: buildPath;


@("Empty") unittest {
    auto tup = Tup();
    tup.output.shouldEqual(banner ~ "\n");
    tup.fileName.shouldEqual("Tupfile");
}


@("Simple D build") unittest {
    auto mainObj  = Target(`main.o`,  `dmd -I$project/src -c $in -of$out`, Target(`src/main.d`));
    auto mathsObj = Target(`maths.o`, `dmd -c $in -of$out`, Target(`src/maths.d`));
    auto app = Target(`myapp`,
                       `dmd -of$out $in`,
                       [mainObj, mathsObj]
        );
    auto build = Build(app);
    auto tup = Tup(build, "/path/to/project");

    tup.lines.shouldEqual(
        [": " ~ buildPath("/path/to/project/src/main.d") ~ " |> dmd -I" ~ buildPath("/path/to/project") ~ "/src -c " ~ buildPath("/path/to/project/src/main.d -of.reggae/objs/myapp.objs/main.o |> .reggae/objs/myapp.objs/main.o"),
         buildPath(": /path/to/project/src/maths.d |> dmd -c /path/to/project/src/maths.d -of.reggae/objs/myapp.objs/maths.o |> .reggae/objs/myapp.objs/maths.o"),
         buildPath(": .reggae/objs/myapp.objs/main.o .reggae/objs/myapp.objs/maths.o |> dmd -ofmyapp .reggae/objs/myapp.objs/main.o .reggae/objs/myapp.objs/maths.o |> myapp")
                              ]);
}
