FROM gcr.io/fuzzer-test-suite/clang-deps-image

RUN apt-get update

# Create directory, and set it as the working directory "."
WORKDIR /~/work

# Add files from "real" filesystem to the container's
COPY . .

# Set env var
ENV WORK /~/work

# Tell Docker to recognize that run-script is an argument
ARG run_cmd

ENTRYPOINT ${run_cmd}
