
includes("@addon/rats-utils/rsteps")

function add_cppcli_step(name, relations, func)
    add_step("cppcli", name, relations, func)
end

function add_cppcli_sequence(...)
    add_sequence("cppcli", ...)
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
-- @warning This only works when this addon is installed manually before invoking an xmake.lua
--          depending on this addon
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
-- @warning This only works when this addon is installed manually before invoking an xmake.lua
--          depending on this addon
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
-- @warning This only works when this addon is installed manually before invoking an xmake.lua
--          depending on this addon
--
function set_dotnet_path(input)
    set_values("dotnet.path", input)
end