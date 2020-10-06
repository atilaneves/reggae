/**
   A module for providing interop between reggae and dub
*/
module reggae.dub.interop;


import reggae.from;
public import reggae.dub.interop.reggaefile;


from!"reggae.dub.info".DubInfo[string] gDubInfos;


@safe:



void writeDubConfig(T)(auto ref T output,
                       in from!"reggae.options".Options options,
                       from!"std.stdio".File file) {
    import reggae.io: log;
    import reggae.dub.info: TargetType;
    import reggae.dub.interop.exec: getDubInfo;

    output.log("Writing dub configuration");

    file.writeln("import reggae.dub.info;");

    if(options.isDubProject) {

        file.writeln("enum isDubProject = true;");
        auto dubInfo = getDubInfo(output, options);
        const targetType = dubInfo.packages.length
            ? dubInfo.packages[0].targetType
            : TargetType.sourceLibrary;

        file.writeln(`const configToDubInfo = assocList([`);

        const keys = () @trusted { return gDubInfos.keys; }();
        foreach(config; keys) {
            file.writeln(`    assocEntry("`, config, `", `, gDubInfos[config], `),`);
        }
        file.writeln(`]);`);
        file.writeln;
    } else {
        file.writeln("enum isDubProject = false;");
    }
}
