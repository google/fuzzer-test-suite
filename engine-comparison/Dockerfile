FROM gcr.io/fuzzer-test-suite/gcloud-clang-deps

# Install clang nightly build
RUN echo "deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial main" >> /etc/apt/sources.list
RUN wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
RUN apt-get update -y
RUN apt-get install -y clang-6.0
RUN ln -s /usr/bin/clang-6.0 /usr/bin/clang
RUN ln -s /usr/bin/clang++-6.0 /usr/bin/clang++

# Create directory, and set it as the working directory "."
WORKDIR /work

# Add files from "real" filesystem to the container's
COPY . .

# Set env var
ENV WORK /work

# ARG run_cmd
# RUN ${run_cmd}
