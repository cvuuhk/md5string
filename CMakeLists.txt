cmake_minimum_required(VERSION 3.18)

# 使用 GCC 14 作为 host compiler（nvcc 12.9 最高支持 GCC 14）
# 必须在 project() 之前设置，否则 CMake 编译器检测阶段会使用默认 GCC
set(CMAKE_CUDA_HOST_COMPILER /usr/bin/g++-14)
set(CMAKE_CXX_COMPILER /usr/bin/g++-14)

# CUDA 架构设置 — sm_89 对应 Ada Lovelace (RTX 40 系列)
set(CMAKE_CUDA_ARCHITECTURES 89)

project(md5ring LANGUAGES CXX CUDA)

# 生成 compile_commands.json（供 clangd/ccls 等 LSP 使用）
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# 编译选项
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CUDA_STANDARD 17)

# 优化级别
set(CMAKE_CXX_FLAGS_RELEASE "-O3")
set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} --expt-relaxed-constexpr")
set(CMAKE_CUDA_FLAGS_RELEASE "-O3")

# 默认使用 Release 模式
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# --- 依赖 ---

find_package(Threads REQUIRED)

# spdlog 快速日志库（header-only，bundled fmt）
set(SPDLOG_SYSTEM_INCLUDES ON CACHE BOOL "Include spdlog headers as system headers (suppress warnings)" FORCE)
add_subdirectory(deps/spdlog)

# --- 可执行文件 ---

# md5 哈希搜索程序
add_executable(md5 src/md5.cu)
target_link_libraries(md5 PRIVATE spdlog::spdlog Threads::Threads)
