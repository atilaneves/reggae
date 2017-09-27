module reggae.io;


void log(O, T...)(auto ref O output, auto ref T args) {
    import std.functional: forward;
    import std.datetime: Clock;
    output.writeln("[Reggae]  ", Clock.currTime, "\t", forward!args);
}
