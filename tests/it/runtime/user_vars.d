module tests.it.runtime.user_vars;

import tests.it.runtime;


immutable reggaefileStr = q{
        import reggae;
        static if(userVars.get("1st", false))
            mixin build!(Target("1st.txt", "touch $out"));
        else
            mixin build!(Target("2nd.txt", "touch $out"));
    };

@("user variables should be available when none were passed")
@Tags("make")
unittest {

    with(Runtime()) {
        writeFile("reggaefile.d", reggaefileStr);

        runReggae("-b", "make");
        make.shouldExecuteOk(testPath);

        // no option passed, static if failed and 2nd was "built"
        shouldNotExist("1st.txt");
        shouldExist("2nd.txt");
    }
}


@("user variables should be available when they were passed")
@Tags("make")
unittest {

    with(Runtime()) {
        writeFile("reggaefile.d", reggaefileStr);

        runReggae("-b", "make", "-d", "1st=true");
        make.shouldExecuteOk(testPath);

        // option passed, static if succeeds and 1st was "built"
        shouldExist("1st.txt");
        shouldNotExist("2nd.txt");
    }
}
