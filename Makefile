all: reggae

reggae: src/reggae.d
	rdmd -Isrc --build-only -ofbin/reggae $<

test: reggae
	cucumber
