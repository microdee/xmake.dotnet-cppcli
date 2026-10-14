
import("core.base.json")
import("core.base.semver")
import("@addon.rats-utils.rtable", {alias = "t"})
import("@addon.rats-utils.rpath", {alias = "p"})
import("@addon.rats-utils.rsteps")

_dotnet = {
    path = nil,
    runtime = "Microsoft.NETCore.App",
    version = "10.0",
    packages = {},

    dll_refs = {},
    steps = nil,
    target = nil,
    xrepo_packages = nil
}

function _dotnet:new(target)
    local result = _dotnet | t.clone(100)
    result.target = target
    result.version = target:values("dotnet.version") or result.version
    result.runtime = target:values("dotnet.runtime") or result.runtime
    result.path = target:values("dotnet.path") or result.path
    result.steps = rsteps.get(target, "cppcli")
    result.steps.context.dotnet = result
    print(".NET:")
    print({
        result.runtime,
        result.version,
        result.path
    })
    return result
end

function _dotnet:get_path()
    if not self.path then
        local dotnet_out = os.iorun("dotnet --list-sdks"):split("\n")
        local line = dotnet_out
            | t.filter(function (i, v)
                    return v:find("^" .. self.version)
            end)
            | t.last()
        local _, _, dotnet_path = line:find("%[(.+)%]")
        self.path = path.directory(dotnet_path)
    end
    if self.path:find(" ", 1, true) then
        local link = vformat("$(tmpdir)/dotnet")
        if not os.exists(link) then
            os.ln(self.path, link)
        else
            assert(os.islink(link))
        end
        self.path = link
    end
    return p(self.path)
end

function _dotnet:refdir()
    return self:get_path() / "packs" / (self.runtime .. ".Ref")
end

function _dotnet:get_packages()
    if not self.xrepo_packages then
        self.xrepo_packages = {}
        for name, pkg in pairs(self.target:pkgs()) do
            local nuget_names = pkg:name():split("::")
            if nuget_names and #nuget_names == 2 then
                table.append(self.xrepo_packages,
                {
                    nuget_names[2],
                    pkg:get("version"):replace("+", ".")
                })
            end
        end
    end
    return table.join(self.packages, self.xrepo_packages)
end

function _dotnet:get_versionsubdir(parentdir)
    local dirs = os.dirs(p(parentdir) / self.version .. "*")
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

function _dotnet:assemblydir()
    return self:get_versionsubdir(self:refdir()) / ("ref/net" .. self.version)
end

function _dotnet:hostdir()
    local hostmain = self:get_path() / "packs" / (self.runtime .. ".Host.win-x64")
    return self:get_versionsubdir(hostmain) / "runtimes/win-x64/native"
end

function _dotnet:nuget_install()
    local nuget = vformat("$(builddir)/nuget/nuget.exe")
    if not os.exists(nuget) then
        import("net.http")
        print("Downloading nuget.exe...")
        http.download("https://dist.nuget.org/win-x86-commandline/latest/nuget.exe", nuget)
    end

    for _, package in ipairs(self:get_packages()) do
        print("Installing nuget package " .. package[1] .. " " .. package[2])
        os.execv(nuget,
        {
            "install", package[1],
            "-Version", package[2],
            "-Framework", "net" .. self.version,
            "-NonInteractive",
            "-OutputDirectory", vformat("$(builddir)/nuget")
        })
    end
end

function _dotnet:fu(dll)
    if not os.exists(dll) then
        print(dll .. " didn't exist")
        return
    end
    if self.dll_refs | t.contains(path.filename(dll)) then return end

    local abs_dll = p.resolve(dll)
    print("Using dll " .. abs_dll)
    self.target:add("cxxflags", "/FU" .. abs_dll)

    table.append(self.dll_refs, path.filename(dll))
end

function _dotnet:fu_dir(dir)
    local dlls = os.files(path.join(dir, "*.dll"))
    for _, dll in ipairs(dlls) do
        self:fu(dll)
    end
end

function _dotnet:ai(dir)
    if not os.exists(dir) then
        print(dir .. " didn't exist")
        return
    end
    local abs_dir = p.resolve(dir);
    print("Using directory: " .. abs_dir)
    self.target:add("cxxflags", "/AI" .. abs_dir)
end

function _dotnet:nuget_use()
    local prefixes = {
        "netstandard",
        "net"
    }
    for _, package in ipairs(os.dirs("$(builddir)/nuget/*")) do
        self:fu_dir(p(package) / "lib/net" .. self.version)

        for _, prefix in ipairs(prefixes) do
            local candidates = os.dirs(p(package) / "lib" / prefix .. "*")
                | t.filter(function(i, v)
                    local dir_version = semver.match(path.filename(v))
                    if dir_version and prefix == "net" then
                        return dir_version < self.version
                    else
                        return dir_version
                    end
                end)
                | t.sort(function(a, b)
                    local a_sem = semver.match(path.filename(a))
                    local b_sem = semver.match(path.filename(b))
                    return a_sem > b_sem
                end)
            self:fu_dir(candidates[1])
        end
    end
end

function _dotnet:config_system()
    self:ai(self:assemblydir().p)
    self:fu_dir(self:assemblydir().p)
end

function get(target)
    local target_dotnet = target:data("dotnet.cppcli")
    if not target_dotnet then
        target_dotnet = _dotnet:new(target)
        target:data_set("dotnet.cppcli", target_dotnet)
    end
    return target_dotnet
end

function main(...) return get(...) end

function declare_steps(target)
    get(target).steps
        :add("nuget_install", {}, function(ctx) ctx.dotnet:nuget_install() end)
        :add_sequence("", { depend = true },
            {"prepare", function(ctx)
                ctx.target:set("policy", "check.auto_ignore_flags", false)
                ctx.target:set("runtimes", "MD")
            end},
            {"use_system_assemblies", function(ctx) ctx.dotnet:config_system() end},
            {"use_nuget_assemblies", function(ctx) ctx.dotnet:nuget_use() end},
            {"config", function(ctx)
                ctx.target:set("exceptions", "none")
                ctx.target:add("cxxflags", "/EHa")
                ctx.target:add("cxxflags", "/clr:netcore")
                ctx.target:add("cxxflags", "/clr:nostdlib")
                ctx.target:add("linkdirs", ctx.dotnet:hostdir().p)
                ctx.target:add("links", "ijwhost.lib")
            end}
        )
        :add("after_build", {}, function(ctx)
            os.cp(ctx.dotnet:hostdir() / "ijwhost.dll".."", p(ctx.target:targetdir()) / "ijwhost.dll".."")

            json.savefile(p(ctx.target:targetdir()) / ctx.target:name() .. ".runtimeconfig.json",
            {
                runtimeOptions = {
                    tfm = "net" .. ctx.dotnet.version,
                    framework = {
                        name = ctx.dotnet.runtime,
                        version = ctx.dotnet.version .. ".0"
                    }
                }
            })
        end)
end