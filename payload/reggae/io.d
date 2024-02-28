module reggae.io;


immutable imported!"std.datetime.systime".SysTime gStartTime;


shared static this() {
    import std.datetime: Clock;
    gStartTime = Clock.currTime;
}


void log(O, T...)(auto ref O output, auto ref T args) {
    import std.functional: forward;
    output.writeln("[Reggae]  ", secondsSinceStartString, "s  ", forward!args);
    output.flush;
}


private string secondsSinceStartString() @safe {
    import std.string: rightJustify;
    import std.conv: to;
    import std.format: format;
    return ("+" ~ (sinceStart / 1000.0).format!"%03.3f"()).rightJustify(8, ' ');
}


private auto sinceStart() @safe {
    import std.datetime: Clock;
    return (Clock.currTime - gStartTime).total!"msecs";
}
