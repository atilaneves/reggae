all: reggae

reggae: bin/reggae

bin/reggae_bootstrap: reggaefile.d src/reggae/reggae_main.d payload/reggae/build.d payload/reggae/rules.d
	dub build --compiler=dmd
	mv bin/reggae bin/reggae_bootstrap

bin/reggae: bin/reggae_bootstrap
	cd bin; ./reggae_bootstrap -b ninja --dflags="-g -debug" ..; ninja

bin/ut:
	cd bin; ninja

test: ut reggae
	cucumber

.PHONY: bin/ut

ut: bin/ut
	bin/ut
