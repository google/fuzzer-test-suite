#!/bin/bash
LIBFUZZER_SRC_DIR=$(dirname $0)  #这个 $内是一个语句
CXX="${CXX:-clang}"  # CXX is clang 这是什么用法 这个好像是取别名   利用 ${} 替换不同的值
echo $CXX

for f in $LIBFUZZER_SRC_DIR/*.cpp; do
  #$CXX -g -O2 -fno-omit-frame-pointer -std=c++11 $f -c &
  $CXX -g -O0 -fno-omit-frame-pointer -std=c++11 $f -c &
done
wait
rm -f libFuzzer.a
ar ru libFuzzer.a Fuzzer*.o #生成新的libfuzzer.a
rm -f Fuzzer*.o

