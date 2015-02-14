all: reggae

reggae: src/reggae/reggae_main.d
	rdmd -Isrc -Jsrc/reggae --build-only -ofbin/reggae $<

test: reggae
	dtest --nodub -Isrc && cucumber

.PHONY: ut

ut: reggae
	dtest --nodub -Isrc
