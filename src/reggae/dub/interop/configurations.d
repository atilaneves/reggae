module reggae.dub.interop.configurations;


import reggae.from;


@safe:


struct DubConfigurations {
    string[] configurations;
    string default_;
    string test; // special `dub test` config
}
