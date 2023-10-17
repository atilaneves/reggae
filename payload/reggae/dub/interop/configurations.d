module reggae.dub.interop.configurations;


@safe:


struct DubConfigurations {
    string[] configurations;
    string default_;
    string test; // special `dub test` config
}
