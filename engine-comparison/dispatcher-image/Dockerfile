FROM gcr.io/gcp-runtimes/ubuntu_16_0_4:latest

# Install clang nightly build
RUN echo "deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial main" >> \
    /etc/apt/sources.list
RUN echo "deb http://packages.cloud.google.com/apt cloud-sdk-xenial main" >> \
    /etc/apt/sources.list
RUN curl https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
RUN apt-get update -y && apt-get install -y git subversion wget cmake automake \
    google-cloud-sdk clang-9 libarchive-dev libfreetype6-dev libglib2.0-dev \
    libcairo2-dev openssl libtool ragel golang libxml2-dev libssl-dev nasm \
    python-dev libgcrypt20-dev libgss-dev liblzma-dev libdbus-1-dev \
    libboost-dev autoconf-archive libbz2-dev libbfd-dev libunwind-dev
RUN ln -s /usr/bin/clang-9 /usr/bin/clang
RUN ln -s /usr/bin/clang++-9 /usr/bin/clang++

# Create directory, and set it as the working directory "."
WORKDIR /work
COPY startup-dispatcher.sh /work/

# Set env var
ENV WORK /work
