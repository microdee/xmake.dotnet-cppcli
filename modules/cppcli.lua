
import("core.base.json")
import("core.base.semver")
import("@addon.rats-utils.rtable")
import("@addon.rats-utils.rpath")

_default_dotnet_options = rtable({
    path = nil,
    runtime = "Microsoft.NETCore.App",
    version = "10.0"
})

_dotnet_options = nil

function _get_path()
    if not _dotnet_options.path then
        local dotnet_out = rtable(os.iorun("dotnet --list-sdks"):split("\n"))
        local line = dotnet_out
            | rtable.filter(function (i, v)
                    return v:find("^" .. _dotnet_options.version)
            end)
            | rtable.last()
        local _, _, dotnet_path = line:find("%[(.+)%]")
        _dotnet_options.path = path.directory(dotnet_path)
    end
    if _dotnet_options.path:find(" ", 1, true) then
        local link = "C:\\temp\\dotnet_link"
        if not os.exists(link) then
            os.ln(_dotnet_options.path, link)
        else
            assert(os.islink(link))
        end
        _dotnet_options.path = link
    end
    return rpath(_dotnet_options.path)
end

function _refdir()
    return _get_path() / "packs" / (_dotnet_options.runtime .. ".Ref")
end

function _get_versionsubdir(parentdir)
    local dirs = os.dirs(rpath(parentdir) / _dotnet_options.version .. "*")
    if #dirs == 0 then return nil end
    if #dirs == 1 then return dirs[1] end
    local latest_version = semver.new("0.0.0")
    local result
    for _, dir in ipairs(dirs) do
        local version = semver.new(path.filename(dir))
        if version > latest_version then
            latest_version = version
            result = dir
        end
    end
    return rpath(result)
end

function _get_version()
    return _dotnet_options.version
end

function _get_runtime()
    return _dotnet_options.runtime
end

function _assemblydir()
    return _get_versionsubdir(_refdir()) / ("ref/net" .. _dotnet_options.version)
end

function _hostdir()
    local hostmain = _get_path() / "packs" / (_dotnet_options.runtime .. ".Host.win-x64")
    return _get_versionsubdir(hostmain) / "runtimes/win-x64/native"
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
            "-Framework", "net" .. _dotnet_options.version,
            "-NonInteractive",
            "-OutputDirectory", vformat("$(builddir)/nuget")
        })
    end
end

_dotnet_dll_refs = rtable()

function _fu(target, dll)
    if not os.exists(dll) then
        print(dll .. " didn't exist")
        return
    end
    if _dotnet_dll_refs | rtable.contains(path.filename(dll)) then return end

    local abs_dll = rpath.resolve(dll)
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

function _ai(target, p)
    if not os.exists(p) then
        print(p .. " didn't exist")
        return
    end
    local abs_p = rpath.resolve(p);
    print("Using directory: " .. abs_p)
    target:add("cxxflags", "/AI" .. abs_p)
end

function _nuget_use(target)
    local prefixes = {
        "netstandard",
        "net"
    }
    for _, package in ipairs(os.dirs("$(builddir)/nuget/*")) do
        _fu_dir(target, rpath(package) / "lib/net" .. _dotnet_options.version)

        for _, prefix in ipairs(prefixes) do
            local candidates = rtable(os.dirs(rpath(package) / "lib" / prefix .. "*"))
                | rtable.filter(function(i, v)
                    local dir_version = semver.match(path.filename(v))
                    if dir_version and prefix == "net" then
                        return dir_version < _get_version()
                    else
                        return dir_version
                    end
                end)
                | rtable.sort(function(a, b)
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
    local dotnet_options = target:values("dotnet.options")
    if dotnet_options then
        _dotnet_options = _default_dotnet_options | rtable.join(dotnet_options)
    else
        _dotnet_options = _default_dotnet_options
    end
end

function on_load_cpp_cli(target)
    local packages = target:values("dotnet.nuget_packages")
    _set_dotnet_options(target)
    _nuget_install(packages)
end

function on_config_cpp_cli(target)
    _dotnet_dll_refs = rtable()
    _set_dotnet_options(target)
    target:set("policy", "check.auto_ignore_flags", false)
    target:set("runtimes", "MD")
    _config_system(target)
    _nuget_use(target)

    target:set("exceptions", "none")
    target:add("cxxflags", "/EHa")
    target:add("cxxflags", "/clr:netcore")
    target:add("cxxflags", "/clr:nostdlib")
    target:add("linkdirs", _hostdir().p)
    target:add("links", "ijwhost.lib")
end

function after_build_cpp_cli(target)

    _set_dotnet_options(target)
    os.cp(_hostdir() / "ijwhost.dll".."", rpath(target:targetdir()) / "ijwhost.dll".."")

    json.savefile(rpath(target:targetdir()) / target:name() .. ".runtimeconfig.json",
    {
        runtimeOptions = {
            tfm = "net" .. _get_version(),
            framework = {
                name = _get_runtime(),
                version = _get_version() .. ".0"
            }
        }
    })
end