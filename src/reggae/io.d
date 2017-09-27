module reggae.io;


void log(O, T...)(auto ref O output, auto ref T args) {
    import std.functional: forward;
    output.writeln("[Reggae]  ", secondsSinceStartString, "s  ", forward!args);
}

private string secondsSinceStartString() @safe {
    import std.string: rightJustify;
    import std.conv: to;
    return ("+" ~ (sinceStart / 1000.0).to!string).rightJustify(8, ' ');
}

private auto sinceStart() @safe {
    import std.datetime: Clock, SysTime;
    static SysTime startTime;

    if(startTime == startTime.init) startTime = Clock.currTime;

    return (Clock.currTime - startTime).total!"msecs";
}
