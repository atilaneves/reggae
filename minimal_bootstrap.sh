dmd -version=minimal -ofbin/reggae -Isrc -Ipayload -Jpayload/reggae src/reggae/{reggae_main,options}.d payload/reggae/{types,build,config}.d payload/reggae/rules/{common,defaults}.d
