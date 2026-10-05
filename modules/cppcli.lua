
import("core.base.json")
import("core.base.semver")
import("@addon.rats-utils.rtable", {alias = "t"})
import("@addon.rats-utils.rpath", {alias = "p"})
import("@addon.rats-utils.rsteps")

_default_dotnet_options = {
    path = nil,
    runtime = "Microsoft.NETCore.App",
    version = "10.0"
}

_dotnet_options = nil

function _get_path()
    if not _dotnet_options.path then
        local dotnet_out = os.iorun("dotnet --list-sdks"):split("\n")
        local line = dotnet_out
            | t.filter(function (i, v)
                    return v:find("^" .. _dotnet_options.version)
            end)
            | t.last()
        local _, _, dotnet_path = line:find("%[(.+)%]")
        _dotnet_options.path = path.directory(dotnet_path)
    end
    if _dotnet_options.path:find(" ", 1, true) then
        local link = vformat("$(tmpdir)/dotnet")
        if not os.exists(link) then
            os.ln(_dotnet_options.path, link)
        else
            assert(os.islink(link))
        end
        _dotnet_options.path = link
    end
    return p(_dotnet_options.path)
end

function _refdir()
    return _get_path() / "packs" / (_dotnet_options.runtime .. ".Ref")
end

function _get_versionsubdir(parentdir)
    local dirs = os.dirs(p(parentdir) / _dotnet_options.version .. "*")
    if #dirs == 0 then return nil end
    if #dirs == 1 then return p(dirs[1]) end
    local latest_version = semver.new("0.0.0")
    local result
    for _, dir in ipairs(dirs) do
        local version = semver.new(path.filename(dir))
        if version > latest_version then
            latest_version = version
            result = dir
        end
    end
    return p(result)
end

function _get_version()
    return _dotnet_options.version
end

function _get_runtime()
    return _dotnet_options.runtime
end

function _assemblydir()
    return _get_versionsubdir(_refdir()) / ("ref/net" .. _get_version())
end

function _hostdir()
    local hostmain = _get_path() / "packs" / (_dotnet_options.runtime .. ".Host.win-x64")
    return _get_versionsubdir(hostmain) / "runtimes/win-x64/native"
end

function cppcli_steps(target)
    local steps = rsteps.get_steps(target, "cppcli")
    steps.context.dotnet = _dotnet_options
    return steps
end

function _nuget_install(packages)
    local nuget = vformat("$(builddir)/nuget/nuget.exe")
    if not os.exists(nuget) then
        import("net.http")
        print("Downloading nuget.exe...")
        http.download("https://dist.nuget.org/win-x86-commandline/latest/nuget.exe", nuget)
    end

    for _, package in ipairs(packages) do
        print("Installing nuget package " .. package[1] .. " " .. package[2])
        os.execv(nuget,
        {
            "install", package[1],
            "-Version", package[2],
            "-Framework", "net" .. _get_version(),
            "-NonInteractive",
            "-OutputDirectory", vformat("$(builddir)/nuget")
        })
    end
end

_dotnet_dll_refs = {}

function _fu(target, dll)
    if not os.exists(dll) then
        print(dll .. " didn't exist")
        return
    end
    if _dotnet_dll_refs | t.contains(path.filename(dll)) then return end

    local abs_dll = p.resolve(dll)
    print("Using dll " .. abs_dll)
    target:add("cxxflags", "/FU" .. abs_dll)

    table.append(_dotnet_dll_refs, path.filename(dll))
end

function _fu_dir(target, dir)
    local dlls = os.files(path.join(dir, "*.dll"))
    for _, dll in ipairs(dlls) do
        _fu(target, dll)
    end
end

function _ai(target, dir)
    if not os.exists(dir) then
        print(dir .. " didn't exist")
        return
    end
    local abs_dir = p.resolve(dir);
    print("Using directory: " .. abs_dir)
    target:add("cxxflags", "/AI" .. abs_dir)
end

function _nuget_use(target)
    local prefixes = {
        "netstandard",
        "net"
    }
    for _, package in ipairs(os.dirs("$(builddir)/nuget/*")) do
        _fu_dir(target, p(package) / "lib/net" .. _dotnet_options.version)

        for _, prefix in ipairs(prefixes) do
            local candidates = os.dirs(p(package) / "lib" / prefix .. "*")
                | t.filter(function(i, v)
                    local dir_version = semver.match(path.filename(v))
                    if dir_version and prefix == "net" then
                        return dir_version < _get_version()
                    else
                        return dir_version
                    end
                end)
                | t.sort(function(a, b)
                    local a_sem = semver.match(path.filename(a))
                    local b_sem = semver.match(path.filename(b))
                    return a_sem > b_sem
                end)
            _fu_dir(target, candidates[1])
        end
    end
end

function _config_system(target)
    _ai(target, _assemblydir().p)
    _fu_dir(target, _assemblydir().p)
end

function _set_dotnet_options(target)
    _dotnet_options = _default_dotnet_options | t.clone();
    for key, value in pairs(_dotnet_options) do
        _dotnet_options[key] = target:values("dotnet." .. key) or value
    end
    print(".NET options:")
    print(_dotnet_options)
end

function on_load_cpp_cli(target)
    _set_dotnet_options(target)
    local steps = cppcli_steps(target)
    steps:add("nuget_install", {}, function(ctx)
        local packages = ctx.target:values("dotnet.nuget_packages") | t.wrap()
        _nuget_install(packages)
    end)
    steps:invoke("nuget_install")

    steps:with_sequence("", {},
        {"prepare", function(ctx)
            _dotnet_dll_refs = {}
            ctx.target:set("policy", "check.auto_ignore_flags", false)
            ctx.target:set("runtimes", "MD")
        end},
        {"use_system_assemblies", function(ctx) _config_system(ctx.target) end},
        {"use_nuget_assemblies", function(ctx) _nuget_use(ctx.target) end},
        {"config", function(ctx)
            ctx.target:set("exceptions", "none")
            ctx.target:add("cxxflags", "/EHa")
            ctx.target:add("cxxflags", "/clr:netcore")
            ctx.target:add("cxxflags", "/clr:nostdlib")
            ctx.target:add("linkdirs", _hostdir().p)
            ctx.target:add("links", "ijwhost.lib")
        end}
    )

    steps:add("after_build", {}, function(ctx)
        os.cp(_hostdir() / "ijwhost.dll".."", p(ctx.target:targetdir()) / "ijwhost.dll".."")

        json.savefile(p(ctx.target:targetdir()) / ctx.target:name() .. ".runtimeconfig.json",
        {
            runtimeOptions = {
                tfm = "net" .. _get_version(),
                framework = {
                    name = _get_runtime(),
                    version = _get_version() .. ".0"
                }
            }
        })
    end)
end

function on_config_cpp_cli(target)
    _set_dotnet_options(target)
    cppcli_steps(target):invoke("config")
end

function after_build_cpp_cli(target)
    _set_dotnet_options(target)
    cppcli_steps(target):invoke("after_build")
end