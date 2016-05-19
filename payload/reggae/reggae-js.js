exports.Target = Target

function Target (outputs, cmd, deps, imps) {

    cmd = cmd || ''

    this.type = "fixed"
    this.command = jsonifiable(cmd, ShellCommand)
    this.outputs = arrayify(outputs)
    this.dependencies = dependify(deps, FixedDependencies)
    this.implicits = dependify(imps, FixedDependencies)

    this.toJson = function () {
        return JSON.stringify(this.jsonify())
    }

    this.jsonify = function () {
        return {type: this.type,
                command: this.command.jsonify(),
                outputs: this.outputs,
                dependencies: this.dependencies.jsonify(),
                implicits: this.implicits.jsonify()
               }
    }
}

function FixedDependencies(deps) {
    this.isDependency = true
    this.targets = arrayify(deps)

    this.jsonify = function() {
        return { "type": "fixed", "targets": this.targets.map(function(t) { return t.jsonify() })}
    }
}

function ShellCommand(cmd) {
    this.type = 'shell'
    this.cmd = cmd

    this.jsonify = function () {
        return this.cmd == '' ? {} : {type: this.type, cmd: this.cmd}
    }
}

function arrayify(val) {
    if(!val) return []
    return val.constructor === Array ? val : [val]
}

function dependify(arg, klass) {
    return (arg && arg.isDependency) ? arg : new klass(arg)
}

function jsonifiable(arg, klass) {
    return arg.jsonify ? arg : new klass(arg)
}


function Build() {

    // mimic splat operator from Python
    targets = Array.prototype.slice.call(arguments, Build.length)

    this.targets = targets

    this.toJson = function() {
        return JSON.stringify(this.jsonify())
    }

    this.jsonify = function() {
        return this.targets.map(function(t) { return t.jsonify() })
    }
}

exports.Build = Build

exports.link = function (options) {
    options.flags = options.flags || ""
    options.dependencies = options.dependencies || []
    options.implicits = options.implicits || []

    return new Target([options.exe_name],
                      new LinkCommand(options.flags),
                      options.dependencies,
                      options.implicits)
}


function LinkCommand(flags) {
    this.flags = flags

    this.jsonify = function () {
        return {type: "link", flags: this.flags}
    }
}


exports.objectFiles = function (options) {
    options.src_dirs = options.src_dirs || []
    options.exclude_dirs = options.exclude_dirs || []
    options.src_files = options.src_files || []
    options.exclude_files = options.exclude_files || []
    options.flags = options.flags || ""
    options.includes = options.includes || []
    options.string_imports = options.string_imports || []

    return new DynamicDependencies('objectFiles', options)
}


function DynamicDependencies(funcName, args) {
    this.isDependency = true
    this.funcName = funcName
    this.args = args

    this.jsonify = function() {
        var result = { type: 'dynamic', func: this.funcName}
        for (var key in this.args) { result[key] = this.args[key] }
        return result
    }
}


exports.staticLibrary = function(name, options) {
    options.name = name
    options.src_dirs = options.src_dirs || []
    options.exclude_dirs = options.exclude_dirs || []
    options.src_files = options.src_files || []
    options.exclude_files = options.exclude_files || []
    options.flags = options.flags || ""
    options.includes = options.includes || []
    options.string_imports = options.string_imports || []

    return new DynamicDependencies('staticLibrary', options)
}


exports.scriptlike = function(options) {

    options.flags = options.flags || ""
    options.includes = options.includes || []
    options.string_imports = options.string_imports || []
    options.link_with = options.link_with || new FixedDependencies([])

    return new Dynamic('scriptlike', options)
}


function Dynamic(funcName, args) {
    this.isDependency = true
    this.funcName = funcName
    this.args = args

    this.jsonify = function() {
        var result = { type: 'dynamic', func: this.funcName}
        for (var key in this.args) {
            result[key] = this.args[key].jsonify ? this.args[key].jsonify() : this.args[key]
        }
        return result
    }
}
