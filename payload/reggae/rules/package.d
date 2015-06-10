module reggae.rules;

public import reggae.core.rules;

version(minimal) {
} else {
    public import reggae.rules.common;
    public import reggae.rules.d;
    public import reggae.rules.dub;
    public import reggae.rules.cpp;
    public import reggae.rules.c;
}
