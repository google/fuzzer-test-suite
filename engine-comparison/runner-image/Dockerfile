FROM gcr.io/gcp-runtimes/ubuntu_16_0_4:latest

RUN echo "deb http://packages.cloud.google.com/apt cloud-sdk-xenial main" >> \
    /etc/apt/sources.list
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
RUN apt-get update -y && apt-get install -y google-cloud-sdk libarchive13 \
    libglib2.0-0 libgss3 libbfd-dev libunwind-dev

# Create directory, and set it as the working directory "."
WORKDIR /work
COPY startup-runner.sh /work/
ENV WORK /work
