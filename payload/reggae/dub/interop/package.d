/**
   A module for providing interop between reggae and dub
*/
module reggae.dub.interop;


string dubConfigSource(O)(ref O output, in imported!"reggae.options".Options options) {
    import reggae.dub.info: TargetType;

    string ret;

    void append(A...)(auto ref A args) {
        import std.conv: text;
        ret ~= text(args, "\n");
    }

    if(!options.isDubProject) {
        append("enum isDubProject = false;");
        return ret;
    }

    auto dubInfos = dubInfos(output, options);

    const targetType = dubInfos["default"].packages.length
        ? dubInfos["default"].packages[0].targetType
        : TargetType.sourceLibrary;

    append("import reggae.dub.info;");
    append("enum isDubProject = true;");
    append(`const configToDubInfo = assocList([`);

    foreach(k, v; dubInfos) {
        append(`    assocEntry("`, k, `", `, v, `),`);
    }
    append(`]);`);

    append;

    return ret;
}


/**
   Returns an associative array of string -> DubInfo, where the string
   is the name of a dub configuration.
 */
imported!"reggae.dub.info".DubInfo[string] dubInfos(O)
    (ref O output,
     in imported!"reggae.options".Options options)
{
    version(Have_dub) {
        import reggae.io: log;
        import reggae.dub.interop.dublib: Dub;
        import std.file: readText;

        output.log("Creating dub instance");
        auto dub = Dub(options);

        dub.fetchDeps(output);

        output.log("Getting dub information");
        auto ret = dub.getDubInfos(output);
        output.log("Got dub build information");

        return ret;
    } else
          throw new Exception("Dub not available, can't get dub information");
}
