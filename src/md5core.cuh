#pragma once

#include <cstdint>
#include <array>

namespace md5core {

  // === MD5 轮函数（host + device 通用）===

  __device__ uint32_t F(uint32_t X, uint32_t Y, uint32_t Z) {
    return (X & Y) | ((~X) & Z);
  }
  __device__ uint32_t G(uint32_t X, uint32_t Y, uint32_t Z) {
    return (X & Z) | (Y & (~Z));
  }
  __device__ uint32_t H(uint32_t X, uint32_t Y, uint32_t Z) {
    return X ^ Y ^ Z;
  }
  __device__ uint32_t I(uint32_t X, uint32_t Y, uint32_t Z) {
    return Y ^ (X | (~Z));
  }

  __device__ uint32_t LEFT_ROTATE(uint32_t v, uint8_t n) {
    return (v << n) | (v >> (32 - n));
  }

  __device__ void FF(uint32_t& A, uint32_t B, uint32_t C, uint32_t D, uint32_t X, uint8_t s, uint32_t T) {
    A = B + LEFT_ROTATE(A + F(B, C, D) + X + T, s);
  }
  __device__ void GG(uint32_t& A, uint32_t B, uint32_t C, uint32_t D, uint32_t X, uint8_t s, uint32_t T) {
    A = B + LEFT_ROTATE(A + G(B, C, D) + X + T, s);
  }
  __device__ void HH(uint32_t& A, uint32_t B, uint32_t C, uint32_t D, uint32_t X, uint8_t s, uint32_t T) {
    A = B + LEFT_ROTATE(A + H(B, C, D) + X + T, s);
  }
  __device__ void II(uint32_t& A, uint32_t B, uint32_t C, uint32_t D, uint32_t X, uint8_t s, uint32_t T) {
    A = B + LEFT_ROTATE(A + I(B, C, D) + X + T, s);
  }

  __device__ uint32_t round_func(uint8_t fn, uint32_t x, uint32_t y, uint32_t z) {
    switch (fn) {
      case 0: return F(x, y, z);
      case 1: return G(x, y, z);
      case 2: return H(x, y, z);
      default: return I(x, y, z);
    }
  }

  // === MD5 初始常量 ===

  constexpr uint32_t MD5_A0 = 0x67452301;
  constexpr uint32_t MD5_B0 = 0xefcdab89;
  constexpr uint32_t MD5_C0 = 0x98badcfe;
  constexpr uint32_t MD5_D0 = 0x10325476;

  // === MD5 T 常量（RFC 1321） ===
  __device__ constexpr uint32_t MD5_T[64] = {
    0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,
    0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,
    0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,
    0x6b901122,0xfd987193,0xa679438e,0x49b40821,
    0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,
    0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,
    0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,
    0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,
    0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,
    0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,
    0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,
    0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
    0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,
    0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,
    0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,
    0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391
  };

  // === 完整 MD5（64 轮），正确支持任意 x[0..15] ===

  __device__ std::array<uint8_t, 16> digest(const uint8_t* buffer) {
    auto* x = reinterpret_cast<const uint32_t*>(buffer);
    uint32_t a = MD5_A0, b = MD5_B0, c = MD5_C0, d = MD5_D0;

    // Round 1 (rounds 0-15): F, x[0..15] in order
    #define RR(a,b,c,d,k,s,i)  { auto f = F(b,c,d); a = b + LEFT_ROTATE(a + f + x[k] + MD5_T[i], s); }
    RR(a,b,c,d, 0, 7, 0); RR(d,a,b,c, 1,12, 1); RR(c,d,a,b, 2,17, 2); RR(b,c,d,a, 3,22, 3);
    RR(a,b,c,d, 4, 7, 4); RR(d,a,b,c, 5,12, 5); RR(c,d,a,b, 6,17, 6); RR(b,c,d,a, 7,22, 7);
    RR(a,b,c,d, 8, 7, 8); RR(d,a,b,c, 9,12, 9); RR(c,d,a,b,10,17,10); RR(b,c,d,a,11,22,11);
    RR(a,b,c,d,12, 7,12); RR(d,a,b,c,13,12,13); RR(c,d,a,b,14,17,14); RR(b,c,d,a,15,22,15);

    // Round 2 (rounds 16-31): G, x[(5*i+1)%16]
    #define RG(a,b,c,d,k,s,i)  { auto f = G(b,c,d); a = b + LEFT_ROTATE(a + f + x[k] + MD5_T[i], s); }
    RG(a,b,c,d, 1, 5,16); RG(d,a,b,c, 6, 9,17); RG(c,d,a,b,11,14,18); RG(b,c,d,a, 0,20,19);
    RG(a,b,c,d, 5, 5,20); RG(d,a,b,c,10, 9,21); RG(c,d,a,b,15,14,22); RG(b,c,d,a, 4,20,23);
    RG(a,b,c,d, 9, 5,24); RG(d,a,b,c,14, 9,25); RG(c,d,a,b, 3,14,26); RG(b,c,d,a, 8,20,27);
    RG(a,b,c,d,13, 5,28); RG(d,a,b,c, 2, 9,29); RG(c,d,a,b, 7,14,30); RG(b,c,d,a,12,20,31);

    // Round 3 (rounds 32-47): H, x[(3*i+5)%16]
    #define RH(a,b,c,d,k,s,i)  { auto f = H(b,c,d); a = b + LEFT_ROTATE(a + f + x[k] + MD5_T[i], s); }
    RH(a,b,c,d, 5, 4,32); RH(d,a,b,c, 8,11,33); RH(c,d,a,b,11,16,34); RH(b,c,d,a,14,23,35);
    RH(a,b,c,d, 1, 4,36); RH(d,a,b,c, 4,11,37); RH(c,d,a,b, 7,16,38); RH(b,c,d,a,10,23,39);
    RH(a,b,c,d,13, 4,40); RH(d,a,b,c, 0,11,41); RH(c,d,a,b, 3,16,42); RH(b,c,d,a, 6,23,43);
    RH(a,b,c,d, 9, 4,44); RH(d,a,b,c,12,11,45); RH(c,d,a,b,15,16,46); RH(b,c,d,a, 2,23,47);

    // Round 4 (rounds 48-63): I, x[(7*i)%16]
    #define RI(a,b,c,d,k,s,i)  { auto f = I(b,c,d); a = b + LEFT_ROTATE(a + f + x[k] + MD5_T[i], s); }
    RI(a,b,c,d, 0, 6,48); RI(d,a,b,c, 7,10,49); RI(c,d,a,b,14,15,50); RI(b,c,d,a, 5,21,51);
    RI(a,b,c,d,12, 6,52); RI(d,a,b,c, 3,10,53); RI(c,d,a,b,10,15,54); RI(b,c,d,a, 1,21,55);
    RI(a,b,c,d, 8, 6,56); RI(d,a,b,c,15,10,57); RI(c,d,a,b, 6,15,58); RI(b,c,d,a,13,21,59);
    RI(a,b,c,d, 4, 6,60); RI(d,a,b,c,11,10,61); RI(c,d,a,b, 2,15,62); RI(b,c,d,a, 9,21,63);

    #undef RR
    #undef RG
    #undef RH
    #undef RI

    a += 0x67452301; b += 0xefcdab89;
    c += 0x98badcfe; d += 0x10325476;

    return {{
      static_cast<uint8_t>(a),       static_cast<uint8_t>(a >> 8),
        static_cast<uint8_t>(a >> 16), static_cast<uint8_t>(a >> 24),
        static_cast<uint8_t>(b),       static_cast<uint8_t>(b >> 8),
        static_cast<uint8_t>(b >> 16), static_cast<uint8_t>(b >> 24),
        static_cast<uint8_t>(c),       static_cast<uint8_t>(c >> 8),
        static_cast<uint8_t>(c >> 16), static_cast<uint8_t>(c >> 24),
        static_cast<uint8_t>(d),       static_cast<uint8_t>(d >> 8),
        static_cast<uint8_t>(d >> 16), static_cast<uint8_t>(d >> 24),
    }};
  }

  // === hex 查找表 ===
  constexpr auto make_hex_lookup() {
    std::array<uint8_t, 256> table{};
    for (uint8_t c = '0'; c <= '9'; ++c) table[c] = c - '0';
    for (uint8_t c = 'a'; c <= 'f'; ++c) table[c] = c - 'a' + 10;
    return table;
  }
  __device__ constexpr auto hex_lookup = make_hex_lookup();

  __device__ std::array<uint8_t, 16> target(const uint8_t* buffer) {
    std::array<uint8_t, 16> target{};

    for (int i = 0; i < 16; i++) {
      target[i] = (md5core::hex_lookup[buffer[i*2]] << 4) + md5core::hex_lookup[buffer[i*2+1]];
    }

    return target;
  }

  __device__ bool checkMatch(std::array<uint8_t, 16> result, std::array<uint8_t, 16> target) {
    for(int i = 0; i < 16; i++) {
      if(result[i] != target[i])
        return false;
    }

    return true;
  }

  // hex 加法：buf[0..31] 作为 base-16 大数，加上 v（带进位）
  __device__ void hex_add(uint8_t* buf, uint64_t v) {
    uint64_t carry = 0;
    for (int pos = 31; pos >= 0 && (v || carry); pos--) {
      uint8_t d = (buf[pos] <= '9') ? buf[pos] - '0' : buf[pos] - 'a' + 10;
      uint64_t sum = d + (v & 0xF) + carry;
      buf[pos] = (sum & 0xF) < 10 ? '0' + (sum & 0xF) : 'a' + ((sum & 0xF) - 10);
      carry = sum >> 4;
      v >>= 4;
    }
  }

  // 从 checkPoint 开始计算
  __global__ void task(const uint8_t* checkPoint, uint8_t* d_out, uint8_t* matched, uint8_t* stop) {
    // d_out[0..15] = target, d_out[16..31] = result
    uint64_t tid = blockIdx.x * blockDim.x + threadIdx.x;
    uint64_t stride = gridDim.x * blockDim.x;  // 92160

    uint8_t buf[64];
    for (int i = 0; i < 64; i++) buf[i] = checkPoint[i];

    // 每个线程从 checkPoint + tid 开始
    hex_add(buf, tid);

    int batchIndex = 0;
    while (!(*stop)) {
      batchIndex ++;
      auto t = target(buf);
      auto r = digest(buf);

      // 当 checkMatch 结果为 true 时，写回内存，打日志并停止程序
      if (checkMatch(r, t)) {
        *matched = true;
        for (int i = 0; i < 16; i++) { d_out[i] = t[i]; d_out[16+i] = r[i]; }
        return;
      }

      // 每 4096 轮将 0 号线程执行进度写回结果
      if (tid == 0 && batchIndex >= 4096) {
        for (int i = 0; i < 16; i++) { d_out[i] = t[i]; d_out[16+i] = r[i]; }
        batchIndex = 0;
      }

      // buf += stride，进入下一轮
      hex_add(buf, stride);
    }
  }
}  // namespace md5core
