#!/usr/bin/env node

var reggae = require('reggae-js')

function getBuild() {
    var reggaefile = require('reggaefile')
    var builds = []

    for(var key in reggaefile) {
        if(reggaefile[key].constructor == reggae.Build) builds.push(reggaefile[key])
    }

    if(builds.length > 1) throw "Too many Build objects"
    if(builds.length == 0)
        throw "Could not find Build object in:\n" + reggaefile.toSource()

    return builds[0]
}


console.log(getBuild().toJson())
