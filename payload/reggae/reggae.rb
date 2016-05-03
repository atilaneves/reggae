require 'json'

# Find the build object
module BuildFinder
  def self.get_build
    builds = []
    ObjectSpace.each_object(Build) { |x| builds << x }
    if builds.length != 1
      fail "Only one Build object may exist, found #{builds.length}"
    end
    builds[0]
  end
end

# Aggregates top-level targets
class Build
  def initialize(*targets)
    @targets = targets
  end

  def to_json
    jsonify.to_json
  end

  def jsonify
    @targets.map { |t| t.jsonify }
  end
end

def build(*targets)
  Build.new(*targets)
end

# A build target
class Target
  attr_reader :outputs, :command, :dependencies, :implicits

  def initialize(outputs, command = '', dependencies = [], implicits = [])
    @outputs = arrayify(outputs)
    @command = jsonifiable(command, ShellCommand)
    @dependencies = dependify(dependencies, FixedDependencies)
    @implicits = dependify(implicits, FixedDependencies)
  end

  def to_json
    jsonify.to_json
  end

  def jsonify
    { type: 'fixed',
      command: @command.jsonify,
      outputs: @outputs,
      dependencies: @dependencies.jsonify,
      implicits: @implicits.jsonify
    }
  end
end

def target(outputs, command = '', dependencies = [], implicits = [])
  Target.new(outputs, command, dependencies, implicits)
end

# A shell command
class ShellCommand
  def initialize(cmd = '')
    @cmd = cmd
  end

  def jsonify
    @cmd == '' ? {} : { type: 'shell', cmd: @cmd }
  end
end

private def arrayify(arg)
  arg.class == Array ? arg : [arg]
end

private def jsonifiable(arg, klass)
  (arg.respond_to? :jsonify) ? arg : klass.new(arg)
end

private def dependify(arg, klass)
  if arg.is_a? Dependencies
    return arg
  end

  if arg.is_a?(Array) && arg.length > 1 && \
     arg.any? { |x| x.is_a? DynamicDependencies }
    return target_concat(arg)
  end

  klass.new(arg)
end

private def target_concat(targets)
  DynamicDependencies.new('targetConcat', dependencies: targets.map { |x| x.jsonify })
end

# Equivalent to link in the D version
class LinkCommand
  def initialize(flags)
    @flags = flags
  end

  def jsonify
    { type: 'link', flags: @flags }
  end
end

def link(exe_name:, flags: '', dependencies: [], implicits: [])
  Target.new([exe_name], LinkCommand.new(flags), dependencies, implicits)
end

def object_files(src_dirs: [], exclude_dirs: [],
                 src_files: [], exclude_files: [],
                 flags: '',
                 includes: [], string_imports: [])
  DynamicDependencies.new('objectFiles',
                          { src_dirs: src_dirs,
                            exclude_dirs: exclude_dirs,
                            src_files: src_files,
                            exclude_files: exclude_files,
                            flags: flags,
                            includes: includes,
                            string_imports: string_imports })
end

class Dependencies
end

# A 'compile-time' known list of dependencies
class FixedDependencies < Dependencies
  def initialize(deps)
    @deps = arrayify(deps)
  end

  def jsonify
    { type: 'fixed', targets: @deps.map { |t| t.jsonify } }
  end
end

# a rule to create a static library
def static_library(name,
                   src_dirs: [],
                   exclude_dirs: [],
                   src_files: [],
                   exclude_files: [],
                   flags: '',
                   includes: [],
                   string_imports: [])
    DynamicDependencies.new('staticLibrary',
                            { name: name,
                              src_dirs: src_dirs,
                              exclude_dirs: exclude_dirs,
                              src_files: src_files,
                              exclude_files: exclude_files,
                              flags: flags,
                              includes: includes,
                              string_imports: string_imports })
end

def scriptlike(src_name:,
               exe_name:,
               flags: '',
               includes: [],
               string_imports: [],
               link_with: [])

  Dynamic.new('scriptlike',
              { src_name: src_name,
                exe_name: exe_name,
                flags: flags,
                includes: includes,
                string_imports: string_imports,
                link_with: dependify(link_with, FixedDependencies) })
end

# A run-time determined list of dependencies
class DynamicDependencies < Dependencies
  def initialize(func_name, args)
    @func_name = func_name
    @args = args
  end

  def jsonify
    base = { type: 'dynamic', func: @func_name }
    base.merge(@args)
  end
end

# dynamic target
class Dynamic
  def initialize(func_name, args)
    @func_name = func_name
    @args = args
  end

  def jsonify
    hash = { type: 'dynamic', func: @func_name }
    @args.each do |k, v|
      if v.respond_to? :jsonify
        hash[k] = v.jsonify
      else
        hash[k] = v
      end
    end
    hash
  end
end
