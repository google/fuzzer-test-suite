
CXX=clang++
CFLAGS=  -O0 -fno-omit-frame-pointer -g -fsanitize=address -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div  -std=c++11


target_name:=$(shell basename $(shell pwd) )-libfuzzer
$(target_name): $(src_OBJ)   $(BROTLI_dec_obj)   $(BROTLI_enc_obj)   libFuzzer.a target.cc
	$(CXX)   $(CFLAGS)   *.o  libFuzzer.a  target.cc   -I SRC/src  -o $(target_name)

SRC_dir = ./SRC/src
SOURCE  := font.cc normalize.cc transform.cc woff2_common.cc woff2_dec.cc woff2_enc.cc glyph.cc table_tags.cc variable_length.cc woff2_out.cc
src_OBJ :=$(SOURCE:%.cc=%.o)
$(src_OBJ): %.o:$(SRC_dir)/%.cc
	$(CXX)   $(CFLAGS)    -I BROTLI/dec -I BROTLI/enc  -c  $^

BROTLI_dec_dir=./BROTLI/dec
BROTLI_dec_src = $(wildcard ${BROTLI_dec_dir}/*.c)
BROTLI_dec_obj=$(notdir $(BROTLI_dec_src:%.c=%.o))
$(BROTLI_dec_obj): %.o: $(BROTLI_dec_dir)/%.c
	$(CXX)   $(CFLAGS)  -c $^

BROTLI_enc_dir=./BROTLI/enc
BROTLI_enc_src = $(wildcard ${BROTLI_enc_dir}/*.cc)
BROTLI_enc_src1=$(filter-out  ${BROTLI_enc_dir}/dictionary.cc , $(BROTLI_enc_src) )
BROTLI_enc_obj=$(notdir $(BROTLI_enc_src1:%.cc=%.o))
$(BROTLI_enc_obj): %.o: $(BROTLI_enc_dir)/%.cc
	$(CXX)   $(CFLAGS)   -c  $^


LibFuzzer_path=../Fuzzer
libFuzzer.a: $(LibFuzzer_path)/libFuzzer.a
	cd $(LibFuzzer_path) && $(MAKE)
	cp $(LibFuzzer_path)/libFuzzer.a ./libFuzzer.a

test: $(BROTLI_enc_obj) #$(BROTLI_enc_obj) #$(BROTLI_dec_obj) 
	sleep 1
	@echo  $(src_OBJ) 
	@echo  $(BROTLI_enc_obj)
	@echo  $(BROTLI_dec_obj) 


clean:
	rm -f   $(SRC_dir)/*.o   $(BROTLI_dec_dir)/*.o  $(BROTLI_enc_dir)/*.o  *.o    libFuzzer.a