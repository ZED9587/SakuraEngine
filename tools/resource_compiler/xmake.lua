executable_module("SkrResourceCompiler", "SKR_RESOURCE_COMPILER", engine_version)
    set_group("02.tools")
    set_exceptions("no-cxx")
    add_rules("c++.codegen", {
        files = {"**.h", "/**.hpp"},
        rootdir = "./"
    })
    public_dependency("SkrToolCore", engine_version)
    public_dependency("SkrTextureCompiler", engine_version)
    public_dependency("SkrShaderCompiler", engine_version)
    public_dependency("SkrGLTFTool", engine_version)
    public_dependency("GameTool", engine_version)
    public_dependency("SkrAnimTool", engine_version)
    add_rules("c++.unity_build", {batchsize = default_unity_batch_size})
    add_files("**.cpp")