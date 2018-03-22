#include <assert.h>
#include <fstream>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>

int print(const char *format, ...) {
  static FILE *f = NULL;
  if (!f) {
    f = fopen("hooks.log", "w");
    assert(f);
  }
  va_list args;
  va_start(args, format);
  int ret = vfprintf(f, format, args);
  va_end(args);
  return ret;
}

extern "C" {
void __sanitizer_cov_trace_pc_guard_init(uint32_t *Start, uint32_t *Stop) {
}

void __sanitizer_cov_trace_pc_guard(uint32_t *Guard) {
  print("%p\n", __builtin_return_address(0));
}

void __sanitizer_cov_trace_cmp8(uint64_t Arg1, uint64_t Arg2) {
  print("%p: cmp8(%lu, %lu)\n", __builtin_return_address(0), Arg1, Arg2);
}

void __sanitizer_cov_trace_const_cmp8(uint64_t Arg1, uint64_t Arg2) {
  print("%p: ccmp8(%lu, %lu)\n", __builtin_return_address(0), Arg1, Arg2);
}

void __sanitizer_cov_trace_cmp4(uint32_t Arg1, uint32_t Arg2) {
  print("%p: cmp4(%u, %u)\n", __builtin_return_address(0), Arg1, Arg2);
}

void __sanitizer_cov_trace_const_cmp4(uint32_t Arg1, uint32_t Arg2) {
  print("%p: ccmp4(%u, %u)\n", __builtin_return_address(0), Arg1, Arg2);
}

void __sanitizer_cov_trace_cmp2(uint16_t Arg1, uint16_t Arg2) {
  print("%p: cmp2(%u, %u)\n", __builtin_return_address(0), Arg1, Arg2);
}

void __sanitizer_cov_trace_const_cmp2(uint16_t Arg1, uint16_t Arg2) {
  print("%p: ccmp2(%u, %u)\n", __builtin_return_address(0), Arg1, Arg2);
}

void __sanitizer_cov_trace_cmp1(uint8_t Arg1, uint8_t Arg2) {
  print("%p: cmp1(%u, %u)\n", __builtin_return_address(0), Arg1, Arg2);
}

void __sanitizer_cov_trace_const_cmp1(uint8_t Arg1, uint8_t Arg2) {
  print("%p: ccmp1(%u, %u)\n", __builtin_return_address(0), Arg1, Arg2);
}

void __sanitizer_cov_trace_switch(uint64_t Val, uint64_t *Cases) {
  // TODO: Print which case is taken.
  print("%p: switch(%lu)\n", __builtin_return_address(0), Val);
}

void __sanitizer_cov_trace_div4(uint32_t Val) {
  print("%p: div4(X, %u)\n", __builtin_return_address(0), Val);
}

void __sanitizer_cov_trace_div8(uint64_t Val) {
  print("%p: div8(X, %lu)\n", __builtin_return_address(0), Val);
}

void __sanitizer_cov_trace_gep(uintptr_t Idx) {
  print("%p: gep(%lu)\n", __builtin_return_address(0), Idx);
}

void __sanitizer_weak_hook_memcmp(void *caller_pc, const void *s1,
                                  const void *s2, size_t n, int result) {
  print("%p: memcmp(%p, %p, %lu) -> %u\n", caller_pc, s1, s2, n, result);
}

void __sanitizer_weak_hook_strncmp(void *caller_pc, const char *s1,
                                   const char *s2, size_t n, int result) {
  print("%p: strncmp(%p, %p, %lu) -> %u\n", caller_pc, s1, s2, n, result);
}

void __sanitizer_weak_hook_strcmp(void *caller_pc, const char *s1,
                                   const char *s2, int result) {
  print("%p: strcmp(%p, %p) -> %u\n", caller_pc, s1, s2, result);
}

void __sanitizer_weak_hook_strncasecmp(void *caller_pc, const char *s1,
                                       const char *s2, size_t n, int result) {
  print("%p: strncasecmp(%p, %p, %lu) -> %u\n", caller_pc, s1, s2, n,
          result);
}

void __sanitizer_weak_hook_strcasecmp(void *caller_pc, const char *s1,
                                      const char *s2, int result) {
  print("%p: strcasecmp(%p, %p) -> %u\n", caller_pc, s1, s2, result);
}

void __sanitizer_weak_hook_strstr(void *caller_pc, const char *s1,
                                  const char *s2, char *result) {
  print("%p: strstr(%p, %p) -> %p\n", caller_pc, s1, s2, result);
}

void __sanitizer_weak_hook_strcasestr(void *caller_pc, const char *s1,
                                      const char *s2, char *result) {
  print("%p: strcasecmp(%p, %p) -> %p\n", caller_pc, s1, s2, result);
}

void __sanitizer_weak_hook_memmem(void *caller_pc, const void *s1,
                                  size_t len1, const void *s2, size_t len2,
                                  void *result) {
  print("%p: memcmp(%p, %lu, %p, %lu) -> %p\n", caller_pc, s1, len1, s2,
          len2, result);
}

extern int LLVMFuzzerTestOneInput(const unsigned char *data, size_t size);
__attribute__((weak)) extern int LLVMFuzzerInitialize(int *argc, char ***argv);

int main(int argc, char **argv) {
  if (LLVMFuzzerInitialize)
    LLVMFuzzerInitialize(&argc, &argv);
  for (int i = 1; i < argc; i++) {
    fprintf(stderr, "Running: %s\n", argv[i]);
    std::ifstream f(argv[i]);
    assert(f);
    f.seekg(0, f.end);
    size_t len = f.tellg();
    f.seekg(0, f.beg);
    char *buf = new char[len];
    f.read(buf, len);
    LLVMFuzzerTestOneInput(reinterpret_cast<unsigned char *>(buf), len);
    delete[] buf;
    fprintf(stderr, "Done:    %s: (%zd bytes)\n", argv[i], len);
  }
}
}  // extern "C"
