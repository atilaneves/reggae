#!/usr/bin/env lua

local reggae = require('reggae')

function get_build()
   local reggaefile = require('reggaefile')
   local builds = {}
   for k, v in pairs(reggaefile) do
      if v.isBuild then
         table.insert(builds, v)
      end
   end

   if builds[2] then
      error 'Only one Build object allowed per file'
   end

   if not builds[1] then
      error 'Could not find a Build object'
   end

   return builds[1]
end

print(get_build():to_json())
