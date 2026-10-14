# .NET C++/CLI xmake addon

A simple [xmake](https://xmake.io) addon for compiling C++/CLI targeting CoreCLR or in English .NET 5+.

C++/CLI has its own limitations which has to be taken account in xmake as well:

* Compiles on Windows only
* Supports only compiling for Windows
* Maximum language version supported is C++ 20 (since 2023)
* Elaborate templating libraries like `range-v3` may break intellisense, still compiles though.

## Install

Through xrepo in your `xmake.lua`

```lua
-- until it's not yet available in mainline xrepo
add_repositories("xrepo-md https://github.com/microdee/xmake-repo.git md")
add_addons("dotnet-cppcli")
```

Or manual installation:

```
xmake addon --install github:microdee/xmake.rats-utils
xmake addon --install github:microdee/xmake.dotnet-cppcli
```

## Nuget packages

Besides handling .NET system assemblies this addon can use nuget packages as well. For example:

```lua
add_requires(
    "nuget::VL.Core 2025.7.4",
    "nuget::Stride.Core.Mathematics 4.3.0"
)

target("mytarget")
    set_kind("shared")
    add_rules("@addon/dotnet-cppcli/cppcli")
    add_files("src/*.cpp")
    add_headerfiles("src/*.h")
    add_packages(
        "nuget::VL.Core",
        "nuget::Stride.Core.Mathematics"
    )
```

This may only support packages with 3-component semantic version `M.M.P` and which may not be pre-release. If pre-release is required or the package version gives you trouble then packages can be also set in script scope

```lua
target("mytarget")
    ...
    on_load(function(target)
        import("@addon.dotnet-cppcli.cppcli")(target).packages =
        {
            { "VL.Core"                 , "2025.7.4"   },
            { "Stride.Core.Mathematics" , "4.3.0.2507" }
        }
    end)
```

> [!NOTE]
> A precise version is recommended in both cases since dotnet nuget defaults to zero missing version components instead of getting latest patch. Precise versions are required when setting packages in script scope.

## dotnet options

Setting dotnet version and locations:

```lua
include("@addon/dotnet-cppcli/desc") -- for set_dotnet_options

target("mytarget")
    add_rules("@addon/dotnet-cppcli/cppcli")
    ...
    set_values("dotnet.version", "8.0")
    set_values("dotnet.path", [[C:\myDotnetInstall]])
```

Note that default values are set for these parameters in the addon itself, so if your target
needs the same parameters then you don't need to call either `set_values`. By default

```lua
{
    version = "10.0", -- indicating net10.0
    runtime = "Microsoft.NETCore.App",
    path = nil, -- determined from system-installed dotnet SDK for given version if it's nil
}
```

## Steps

`cppcli` rule internally uses a [step-graph](https://github.com/microdee/xmake.rats-utils#rsteps) for its tasks, so others may hook into build actions at precise steps. Which are:

```
name                  invoked on
                      
nuget_install         (after_load)
prepare               (on_config)
use_system_assemblies (on_config)
use_nuget_assemblies  (on_config)
config                (on_config)
after_build           (after_build)
```

For example

```lua
target("my-stuff")
    ...
    on_load(function(target)
        import("@addon.dotnet-cppcli.cppcli")(target).steps
            :add("install_lib",
                { triggered_by = "after_build"},
                function(ctx)
                    -- do something
                end
            )
            :add("cursed_thing",
                { dependent_for = "use_system_assemblies" }
                function(ctx)
                    -- idk do something with dotnet I guess
                end
            )
    end)
```