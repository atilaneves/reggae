all: reggae

reggae: bin/reggae

bin/reggae_bootstrap: reggaefile.d
	dub build --compiler=dmd
	touch bin/reggae_bootstrap

bin/reggae: bin/reggae_bootstrap reggaefile.d src/reggae/reggae_main.d src/reggae/options.d src/reggae/dub_json.d payload/reggae/build.d payload/reggae/rules.d payload/reggae/ninja.d payload/reggae/makefile.d
	cd bin; ./reggae -b ninja --dflags="-g -debug" ..; ninja

bin/ut: reggae
	cd bin; ninja

test: ut reggae
	cucumber

.PHONY: bin/ut

ut: bin/ut
	bin/ut

cuke: reggae
	cucumber
