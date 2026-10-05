
includes("@addon/rats-utils/rsteps")

function add_cppcli_step(name, relations, func)
    add_step("cppcli", name, relations, func)
end

function add_cppcli_sequence(...)
    add_sequence("cppcli", ...)
end

--!
-- Usage:
-- @code
-- include("@addon/dotnet-cppcli/desc")
-- 
-- target("mytarget")
--     ...
--     add_nuget_packages(
--         {"VL.Core", "2026.8.0-0131-g2f3a63d2aa"},
--         {"Stride.Core.Mathematics", "4.3.0.2507"}
--     )
-- @endcode
--
-- @todo Support nuget packages which ship assemblies for earlier versions of .NET, if they don't
--       have assemblies for exactly the version that is used by the target.
--
function add_nuget_packages(...)
    add_values("dotnet.nuget_packages", ...)
end

--!
-- Setting dotnet version:
-- @code
-- include("@addon/dotnet-cppcli/desc")
-- 
-- target("mytarget")
--     ...
--     set_dotnet_version("8.0")
-- @endcode
-- Note that default values are set for these parameters in the addon itself, so if your target
-- needs the same parameters then you don't need to call `set_dotnet_*` functions at all
--
function set_dotnet_version(input)
    set_values("dotnet.version", input)
end

--!
-- Setting dotnet runtime. You may never need to change this.
-- @code
-- include("@addon/dotnet-cppcli/desc")
-- 
-- target("mytarget")
--     ...
--     set_dotnet_runtime("Microsoft.NETCore.App")
-- @endcode
-- Note that default values are set for these parameters in the addon itself, so if your target
-- needs the same parameters then you don't need to call `set_dotnet_*` functions at all
--
function set_dotnet_runtime(input)
    set_values("dotnet.runtime", input)
end

--!
-- Setting dotnet path. You may never need to change this.
-- @code
-- include("@addon/dotnet-cppcli/desc")
-- 
-- target("mytarget")
--     ...
--     set_dotnet_path("C:\\my\\dotnet\\path")
-- @endcode
-- Note that default values are set for these parameters in the addon itself, so if your target
-- needs the same parameters then you don't need to call `set_dotnet_*` functions at all
--
function set_dotnet_path(input)
    set_values("dotnet.path", input)
end