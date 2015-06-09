module reggae.rules;


public import reggae.rules.defaults;
public import reggae.rules.common;
public import reggae.rules.d;

version(minimal) {}
else {
    public import reggae.rules.dub;
    public import reggae.rules.cpp;
    public import reggae.rules.c;
}
