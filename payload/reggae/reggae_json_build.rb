#!/usr/bin/env ruby

require 'reggae'
require 'reggaefile'

puts BuildFinder.get_build.to_json
