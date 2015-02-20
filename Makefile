all: reggae

reggae:
	dub build --compiler=dmd

test: reggae ut
	cucumber

.PHONY: ut

ut:
	dub test --compiler=dmd
