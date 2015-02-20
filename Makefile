all: reggae

reggae:
	dub build --compiler=dmd

test: ut reggae
	cucumber

.PHONY: ut

ut:
	dub test --compiler=dmd
