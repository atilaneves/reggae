all: reggae

reggae: src/reggae_main.d
	rdmd -Isrc -Jsrc --build-only -ofbin/reggae $<

test: reggae
	dtest --nodub -Isrc && cucumber
