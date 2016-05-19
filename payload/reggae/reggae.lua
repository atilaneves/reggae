local JSON = require('JSON')

local Build = {}
Build.__index = Build
setmetatable(Build, {
                __call = function(cls, ...)
                   return cls.new(...)
                end,
})

local Target = {}
Target.__index = Target

setmetatable(Target, {
                __call = function (cls, ...)
                   return cls.new(...)
                end,
})

local ShellCommand = {}
ShellCommand.__index = ShellCommand

setmetatable(ShellCommand, {
                __call = function (cls, ...)
                   return cls.new(...)
                end
})



local LinkCommand = {}
LinkCommand.__index = LinkCommand

setmetatable(LinkCommand, {
                __call = function (cls, ...)
                   return cls.new(...)
                end
})


local FixedDependencies = {}
FixedDependencies.__index = FixedDependencies

setmetatable(FixedDependencies, {
                __call = function (cls, ...)
                   return cls.new(...)
                end
})

local DynamicDependencies = {}
DynamicDependencies.__index = DynamicDependencies

setmetatable(DynamicDependencies, {
                __call = function (cls, ...)
                   return cls.new(...)
                end
})


function Build.new(target)
   local self = setmetatable({}, Build)
   self.targets = {target}
   self.isBuild = true
   return self
end

function Build:to_json()
   return JSON:encode(self:jsonify())
end

function Build:jsonify()
   targets = {}
   for k, v in pairs(self.targets) do
      targets[k] = v:jsonify()
   end

   return targets
end

function Target.new(outputs, cmd, deps, imps)
   local self = setmetatable({}, Target)

   cmd = cmd or ''

   self.command = jsonifiable(cmd, ShellCommand)
   self.outputs = arrayify(outputs)
   self.dependencies = dependify(deps, FixedDependencies)
   self.implicits = dependify(imps, FixedDependencies)

   return self
end

function Target:to_json()
   return JSON:encode(self:jsonify())
end

function Target:jsonify()
   return {
           type = 'fixed',
           command = self.command:jsonify(),
           outputs = self.outputs,
           dependencies = self.dependencies:jsonify(),
           implicits = self.implicits:jsonify(),
   }
end

function jsonifiable(arg, cls)
   return (arg and arg.jsonify) and arg or cls.new(arg)
end

function dependify(arg, cls)
   return (arg and arg.isDependency) and arg or cls.new(arg)
end

function arrayify(arg)
   if arg == nil then
      return {}
   end

   if isArray(arg) then
      return arg
   else
      return {arg}
   end
end

function isArray(arg)
   if type(arg) ~= 'table' then
      return false
   end

   for k, v in pairs(arg) do
      if type(k) ~= 'number' then
         return false
      end
   end

   return true
end

function ShellCommand.new(cmd)
   local self = setmetatable({}, ShellCommand)
   self.cmd = (cmd == '') and {} or {type='shell', cmd=cmd}
   return self
end

function ShellCommand:jsonify()
   return self.cmd
end

function FixedDependencies.new(deps)
   local self = setmetatable({}, FixedDependencies)
   self.isDependency = true
   self.targets = arrayify(deps)
   return self
end


function FixedDependencies:jsonify()
   local targets = {}
   for k, v in pairs(self.targets) do
      targets[k] = v:jsonify()
   end
   return {type = 'fixed', targets = targets}
end

function link(options)
   options.flags = options.flags or ''
   options.dependencies = options.dependencies or {}
   options.implicits = options.implicits or {}

    return Target.new(options.exe_name,
                      LinkCommand.new(options.flags),
                      options.dependencies,
                      options.implicits)

end

function LinkCommand.new(flags)
   local self = setmetatable({}, LinkCommand)
   self.flags = flags
   return self
end

function LinkCommand:jsonify()
   return {type = 'link', flags = self.flags}
end

function object_files(options)

   options.src_dirs = options.src_dirs or {}
   options.exclude_dirs = options.exclude_dirs or {}
   options.src_files = options.src_files or {}
   options.exclude_files = options.exclude_files or {}
   options.flags = options.flags or ""
   options.includes = options.includes or {}
   options.string_imports = options.string_imports or {}

   return DynamicDependencies.new('objectFiles', options)
end

function DynamicDependencies.new(func_name, args)
   local self = setmetatable({}, DynamicDependencies)

   self.isDependency = true
   self.func_name = func_name
   self.args = args

   return self
end

function DynamicDependencies:jsonify()
   local result = {type = 'dynamic', func = self.func_name}

   for k, v in pairs(self.args) do
      if v.jsonify then
         result[k] = v:jsonify()
      else
         result[k] = v
      end
   end

   return result
end

function static_library(name, options)
   options.name = name
   options.src_dirs = options.src_dirs or {}
   options.exclude_dirs = options.exclude_dirs or {}
   options.src_files = options.src_files or {}
   options.exclude_files = options.exclude_files or {}
   options.flags = options.flags or ""
   options.includes = options.includes or {}
   options.string_imports = options.string_imports or {}

   return DynamicDependencies('staticLibrary', options)
end

function scriptlike(options)

    options.flags = options.flags or ""
    options.includes = options.includes or {}
    options.string_imports = options.string_imports or {}
    options.link_with = options.link_with or FixedDependencies.new({})

    return DynamicDependencies.new('scriptlike', options)
end


return {
   Build = Build,
   Target = Target,
   link = link,
   object_files = object_files,
   static_library = static_library,
   scriptlike = scriptlike,
}
