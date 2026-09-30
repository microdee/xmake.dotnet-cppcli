
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
-- Setting dotnet version and locations:
-- @code
-- include("@addon/dotnet-cppcli/desc")
-- 
-- target("mytarget")
--     ...
--     set_dotnet_options({
--         version = "8.0"
--     })
-- @endcode
-- Note that default values are set for these parameters in the addon itself, so if your target
-- needs the same parameters then you don't need to call `set_dotnet_options`
--
-- @todo Automatically determine the dotnet installation folder
--
function set_dotnet_options(options)
    set_values("dotnet.options", options)
end