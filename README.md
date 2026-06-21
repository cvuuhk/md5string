# md5ring

CUDA GPU MD5 哈希碰撞搜索——寻找一个 32 字符 hex 字符串，使其 MD5 摘要等于该 hex 字符串代表的原始字节。

## 原理

92,160 个 GPU 线程并发，每个线程把 32 字符 hex 字符串当作 base-16 大整数逐轮递增，计算 `MD5(输入) == hex解码(输入)` 是否成立。

- **搜索空间**：最大 2¹²⁸（32 个可变 hex 位）
- **断点续跑**：每 5 秒自动保存进度到 `checkPoint.txt`，重启自动恢复
- **优雅停止**：Ctrl+C 保存进度后退出

## 环境要求

| 组件 | 最低版本 |
|------|---------|
| NVIDIA GPU | SM 7.5+（RTX 2060 / GTX 1660 Ti 及以上） |
| CUDA Toolkit | 12.x |
| 宿主编译器 | GCC 14（或修改 `CMakeLists.txt`） |
| CMake | ≥ 3.18 |
| spdlog | 已内置于 `deps/spdlog` |

## 构建

```bash
cmake -S . -B build && cmake --build build
```

如需生成可移植二进制（支持多架构 GPU）：

```cmake
set(CMAKE_CUDA_ARCHITECTURES 75 80 86 89)
```

## 用法

```bash
./build/md5
```

1. 若 `checkPoint.txt` 存在则从中读取 32 hex 字符作为起点，否则创建全零文件
2. 启动 GPU kernel，每 5 秒打印当前进度（result + target 值）
3. 按 `Ctrl+C` 保存进度退出，下次启动自动续跑

## 文件说明

| 文件 | 用途 |
|------|------|
| `src/md5.cu` | Host 端：checkpoint 读写、信号处理、CUDA 内存管理 |
| `src/md5core.cuh` | GPU 端：完整 MD5（64 轮 RFC 1321）、hex 大数加法、匹配检测 |
| `CMakeLists.txt` | 构建配置 |
| `deps/spdlog/` | 内置日志库 |
| `checkPoint.txt` | 持久化进度（运行时自动创建） |

## 配置常量

在 `src/md5.cu` 中定义：

| 常量 | 默认值 | 含义 |
|------|--------|------|
| `BLOCK_DIM` | 256 | 每 block 线程数 |
| `GRID_DIM` | 360 | grid 中 block 数（60 SM × 6） |
| `CHECKPOINT_INTERVAL` | 4096 | 每多少轮 GPU 写一次进度 |

## 技术要点

- **完整 MD5 实现在 GPU 上**：标准 RFC 1321 实现（64 轮，F/G/H/I 四个轮函数，每轮按排列访问 x[k]），无预计算捷径
- **独立 CUDA stream 实现非阻塞 host-device IO**：通过 `cudaStreamNonBlocking` 在 kernel 运行时异步读取进度、发送停止信号
- **线程 0 单写 Checkpoint**：thread 0 的索引始终是所有线程中的全局最小值，保证不遗漏候选值
- **终端处理**：关闭 `ECHOCTL` 标志，Ctrl+C 时不再显示 `^C` 符号
