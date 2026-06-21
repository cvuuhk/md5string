#include <chrono>
#include <csignal>
#include <cstdint>
#include <array>
#include <fstream>
#include <string>
#include <termios.h>
#include <thread>
#include <unistd.h>
#include <cuda_runtime.h>
#include <spdlog/spdlog.h>
#include <spdlog/fmt/bundled/format.h>

#include "md5core.cuh"

constexpr const char* CHECKPOINT_FILE = "checkPoint.txt";

std::string printHex(std::array<uint8_t, 16> a) {
  std::string hex;
  for (auto b : a) hex += fmt::format("{:02x}", b);
  return hex;
}

std::array<uint8_t, 64> initCheckPoint() {
  std::array<uint8_t, 32> prefix{};
  std::ifstream in(CHECKPOINT_FILE, std::ios::binary);
  if (in.is_open()) {
    in.read(reinterpret_cast<char*>(prefix.data()), 32);
    spdlog::info("Read checkPoint.txt: {} bytes", in.gcount());
  } else {
    spdlog::info("checkPoint.txt not found, creating with 32 zero chars");
    std::ofstream out(CHECKPOINT_FILE, std::ios::binary);
    for (int i = 0; i < 32; i++) out.put('0');
    out.close();
    for (int i = 0; i < 32; i++) prefix[i] = '0';
  }

  spdlog::info("checkPoint: {}", std::string(reinterpret_cast<char*>(prefix.data()), 32));

  // 模板：前 32 字节从 checkPoint 读入，后 32 字节固定为 MD5 填充
  std::array<uint8_t, 64> check_point{};
  for (int i = 0; i < 32; i++) check_point[i] = prefix[i];
  check_point[32] = 0x80;
  // 消息长度 256 bits = 0x0000000000000100 LE: LSB at [56], MSB at [63]
  check_point[56] = 0x00; check_point[57] = 0x01; check_point[58] = 0x00; check_point[59] = 0x00;
  check_point[60] = 0x00; check_point[61] = 0x00; check_point[62] = 0x00; check_point[63] = 0x00;

  return check_point;
}

// 将 target (16 bytes) 转为 hex 字符串写入 checkPoint.txt
void refreshCheckPoint(std::array<uint8_t, 16> target) {
  std::ofstream out(CHECKPOINT_FILE, std::ios::binary | std::ios::trunc);
  for (auto b : target) {
    out.put((b >> 4) < 10 ? '0' + (b >> 4) : 'a' + ((b >> 4) - 10));
    out.put((b & 0xF) < 10 ? '0' + (b & 0xF) : 'a' + ((b & 0xF) - 10));
  }
  spdlog::info("checkPoint updated: {}", printHex(target));
}

uint8_t stop = false;

void signalHandler(int) {
  spdlog::info("停止中。。。");
  stop = true;
}

void initSignalHandle() {
  std::signal(SIGINT, signalHandler);
  std::signal(SIGTERM, signalHandler);
}

// 禁用终端回显控制字符（不再打印 ^C）
void initTerminalDisplay() {
  static struct termios saved_tio;
  tcgetattr(STDIN_FILENO, &saved_tio);
  struct termios raw = saved_tio;
  raw.c_lflag &= ~ECHOCTL;
  tcsetattr(STDIN_FILENO, TCSANOW, &raw);
  std::atexit([]{ tcsetattr(STDIN_FILENO, TCSANOW, &saved_tio); });
}

int main() {
  initSignalHandle();
  initTerminalDisplay();
  auto check_point = initCheckPoint();

  uint8_t *d_check_point, *d_buffer, matched = false, *d_matched, *d_stop;
  std::array<uint8_t, 32> buffer;          // [0..15] = target, [16..31] = result
  auto target = [&]() -> std::array<uint8_t,16>& { return *reinterpret_cast<std::array<uint8_t,16>*>(buffer.data()); };
  auto result = [&]() -> std::array<uint8_t,16>& { return *reinterpret_cast<std::array<uint8_t,16>*>(buffer.data()+16); };

  // 1. 分配设备内存
  cudaMalloc(&d_check_point, 64);
  cudaMalloc(&d_buffer, 32);        // target + result 连续，一次读回防撕裂
  cudaMalloc(&d_matched, 1);
  cudaMalloc(&d_stop, 1);
  cudaMemcpy(d_check_point, check_point.data(), 64, cudaMemcpyHostToDevice);
  cudaMemcpy(d_stop, &stop, 1, cudaMemcpyHostToDevice);
  cudaMemcpy(d_matched, &matched, 1, cudaMemcpyHostToDevice);

  // 2. 异步启动 kernel + 独立 stream 用于 host↔device 通信
  cudaStream_t io_stream;
  cudaStreamCreateWithFlags(&io_stream, cudaStreamNonBlocking);
  md5core::task<<<360, 256>>>(d_check_point, d_buffer, d_matched, d_stop);

  while (!stop && !matched) {
    std::this_thread::sleep_for(std::chrono::seconds(5));

    // 3. 一次读回 32 字节（target + result 连续，不撕裂）
    cudaMemcpyAsync(buffer.data(), d_buffer, 32, cudaMemcpyDeviceToHost, io_stream);
    cudaMemcpyAsync(&matched, d_matched, 1, cudaMemcpyDeviceToHost, io_stream);
    cudaStreamSynchronize(io_stream);

    spdlog::info("result: {}, target: {}", printHex(result()), printHex(target()));
  }

  // 用独立 stream 发送 stop 信号（不排队在 kernel 后）
  cudaMemcpyAsync(d_stop, &stop, 1, cudaMemcpyHostToDevice, io_stream);
  cudaStreamSynchronize(io_stream);

  if (matched) {
    spdlog::info("matched! target: {}, result: {}", printHex(target()), printHex(result()));
  }

  cudaDeviceSynchronize();
  cudaStreamDestroy(io_stream);

  // 4. 清理
  cudaFree(d_check_point);
  cudaFree(d_buffer);
  cudaFree(d_matched);
  cudaFree(d_stop);

  // 5. 更新 checkPoint.txt
  refreshCheckPoint(target());

  return 0;
}
