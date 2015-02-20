all: reggae

reggae: src/reggae/reggae_main.d
	rdmd -debug -g --compiler=dmd -Isrc -Jsrc/reggae --build-only -ofbin/reggae $<

test: reggae
	dtest --nodub -Isrc && cucumber

.PHONY: ut

ut:
	dub test --compiler=dmd
