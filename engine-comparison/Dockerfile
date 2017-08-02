FROM gcr.io/fuzzer-test-suite/gcloud-clang-deps

RUN apt-get update

# Create directory, and set it as the working directory "."
WORKDIR /work

# Add files from "real" filesystem to the container's
COPY . .

# Set env var
ENV WORK /work

# ARG run_cmd
# RUN ${run_cmd}
