sdl2_includes_dir = "$(projectdir)/thirdparty/SDL2"

if (is_os("windows")) then 
    target("SkrRT")
        add_links("SDL2", {public = true})
elseif (is_os("macosx") or is_os("linux")) then
    add_requires("libsdl", {configs = {shared = true}})
    target("SkrRT")
        add_packages("libsdl", {public = true})
else

end

target("SkrRoot")
    add_includedirs(sdl2_includes_dir, {public = true})