# .NET C++/CLI xmake addon

A simple [xmake](https://xmake.io) addon for compiling C++/CLI targeting CoreCLR or in English .NET 5+.

Through xrepo in your `xmake.lua`

```lua
add_repositories("xrepo-md https://github.com/microdee/xmake-repo.git md") -- until it's not yet available in mainline xrepo
add_addons("dotnet-cppcli")
```

Or manual installation:

```
xmake addon --install github:microdee/xmake.rats-utils
xmake addon --install github:microdee/xmake.dotnet-cppcli
```

## Features

Handle including .NET system assemblies and manage nuget packages. For example:

```lua
add_requires("nuget::VL.Core 2025.7")
add_requires("nuget::Stride.Core.Mathematics 4.3")

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

As you can see precise version is required unfortunately.

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
    version = "10.0" -- indicating net10.0
    runtime = "Microsoft.NETCore.App",
    path = nil, -- determined from system-installed dotnet SDK for given version if it's nil
}
```

> [!IMPORTANT]
> C++/CLI only supports language versions up to C++ 20

`cppcli` rule internally uses a [step-graph](https://github.com/microdee/xmake.rats-utils#rsteps) for its tasks, so others may hook into build actions at precise steps. Which are:

```
name                  invoked on
                      
nuget_install         (on_load)
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
    add_cppcli_step("install_lib", { triggered_by = "after_build"}, function(ctx)
        local output = path.absolute("../lib/net" .. ctx.dotnet.version)
        if os.exists(output) then
            os.rmdir(output)
        end
        os.cp(path.absolute(ctx.target:targetdir()), output)
    end)
```