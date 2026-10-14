
add_rules("mode.debug", "mode.release")
set_languages("c++20")

add_requires(
    "nuget::VL.Core 2025.7.4",
    "nuget::Stride.Core.Mathematics 4.3.0"
)

target("CppCliTest")
    set_kind("shared")
    add_rules("@addon/dotnet-cppcli/cppcli")
    add_files("src/*.cpp")
    -- add_headerfiles("src/*.h")
    -- set_values("dotnet.version", "8.0")
    add_packages(
        "nuget::VL.Core",
        "nuget::Stride.Core.Mathematics"
    )