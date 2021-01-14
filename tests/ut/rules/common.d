module tests.ut.rules.common;


import reggae;
import unit_threaded;


@("objFileName")
unittest {
    "foo.d".objFileName.should == "foo" ~ objExt;
    "foo._.d".objFileName.should == "foo._" ~ objExt;
}
