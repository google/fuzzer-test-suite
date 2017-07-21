#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh
GNUTLS_ST=ftp://ftp.gnutls.org/gcrypt/gnutls/v3.5/gnutls-3.5.0.tar.xz
DF="-DFUZZER_DISABLE_SIGNCHECK -Wno-expansion-to-defined"
PATCH=gnutls_3.5.0_no_sig.patch

wget_gnutls() {
	if ! [ -d SRC/gnutls-3.5.0 ]; then
		wget ${GNUTLS_ST}

		if [ -f gnutls-3.5.0.tar.xz ]; then
			mkdir -p SRC
			unxz gnutls-3.5.0.tar.xz
			tar xf gnutls-3.5.0.tar
			mv gnutls-3.5.0 SRC
		fi
		rm -f *gz *tar
	fi
}

build_lib() {
  rm -rf BUILD
  cp -rf SRC/gnutls-3.5.0 BUILD
  cp $SCRIPT_DIR/$PATCH BUILD
  (cd BUILD &&
    patch -p1 < ${PATCH} &&
    CC="$CC" ./configure  --disable-doc \
    --with-default-trust-store-dir=/etc/ssl/certs \
    --prefix=`pwd` --exec-prefix=`pwd` CFLAGS="$FUZZ_CXXFLAGS $DF" \
     CXXFLAGS="$FUZZ_CXXFLAGS $DF" --with-included-libtasn1 \
     --without-p11-kit && make -j $JOBS && make install
  )
}

# wget_gnutls
# build_lib
# build_fuzzer
set -x
GNUTLS=`pwd`/BUILD
INC_GNUTLS=`pkg-config ${GNUTLS}/lib/pkgconfig/gnutls.pc --cflags --libs`
LD_GNUTLS="-L${GNUTLS}/lib -lgnutls -lnettle -lhogweed -lgmp -lz"
$CXX $CXXFLAGS $SCRIPT_DIR/target.cc $LIB_FUZZING_ENGINE ${INC_GNUTLS} \
	-DCERT_PATH=\"$CERTPATH/\" \
    ${LD_GNUTLS} -o ${EXECUTABLE_NAME_BASE}${BINARY_NAME_EXT}

$CXX $CXXFLAGS $SCRIPT_DIR/driver.cc $LIB_FUZZING_ENGINE ${INC_GNUTLS} \
	-DCERT_PATH=\"$CERTPATH/\" \
    ${LD_GNUTLS} -o $SCRIPT_DIR/driver
