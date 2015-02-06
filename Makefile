all: reggae

reggae: src/main.d
	rdmd -Isrc --build-only -ofbin/reggae $<

test: reggae
	dtest --nodub -Isrc && cucumber
