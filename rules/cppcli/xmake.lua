
--!
-- Set required compiler flags for C++/CLI development, handle including .NET system assemblies
-- and manage nuget packages. For example:
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
-- As you can see precise version is required unfortunately.
--
-- Setting dotnet version and locations:
-- @code
-- include("@addon/dotnet-cppcli/desc")
-- 
-- target("mytarget")
--     ...
--     set_dotnet_sdk({
--         version = "8.0",
--         path = "C:\\myDotnetInstall"
--     })
-- @endcode
-- Note that default values are set for these parameters in the addon itself, so if your target
-- needs the same parameters then you don't need to call `set_dotnet_sdk`
--
-- @note C++/CLI only supports language versions up to C++ 20
-- 
-- @todo Use the built-in nuget package manager for C#, I wrote my own because I felt that was
--       simpler to do, but of course it cannot take part in the xrepo package management systems
--
rule("cppcli")
    on_load(function (target)
        import("@self.cppcli").on_load_cpp_cli(target)
    end)
    on_config(function (target)
        import("@self.cppcli").on_config_cpp_cli(target)
    end)
    after_build(function (target)
        import("@self.cppcli").after_build_cpp_cli(target)
    end)