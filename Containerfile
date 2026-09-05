FROM docker.io/library/ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install base tools
RUN apt-get update -qq && apt-get install -y -qq \
    curl \
    build-essential \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install GCC 9.4.0-1ubuntu1~20.04.1 for the final Rust link
RUN curl -sL -o /tmp/libgcc9.deb https://snapshot.ubuntu.com/ubuntu/20220331T000000Z/pool/main/g/gcc-9/libgcc-9-dev_9.4.0-1ubuntu1~20.04.1_amd64.deb \
    && curl -sL -o /tmp/gcc9.deb https://snapshot.ubuntu.com/ubuntu/20220331T000000Z/pool/main/g/gcc-9/gcc-9_9.4.0-1ubuntu1~20.04.1_amd64.deb \
    && curl -sL -o /tmp/cpp9.deb https://snapshot.ubuntu.com/ubuntu/20220331T000000Z/pool/main/g/gcc-9/cpp-9_9.4.0-1ubuntu1~20.04.1_amd64.deb \
    && curl -sL -o /tmp/base9.deb https://snapshot.ubuntu.com/ubuntu/20220331T000000Z/pool/main/g/gcc-9/gcc-9-base_9.4.0-1ubuntu1~20.04.1_amd64.deb \
    && dpkg -i /tmp/base9.deb /tmp/cpp9.deb /tmp/gcc9.deb /tmp/libgcc9.deb \
    && rm -f /tmp/*.deb

# Install GCC 9.3.0-17ubuntu1~20.04 in /opt/gcc-9.3 for C compilation
RUN mkdir -p /opt/gcc-9.3 \
    && curl -sL https://launchpadlibrarian.net/492520971/cpp-9_9.3.0-17ubuntu1~20.04_amd64.deb | dpkg -x - /opt/gcc-9.3 \
    && curl -sL https://launchpadlibrarian.net/492520976/gcc-9_9.3.0-17ubuntu1~20.04_amd64.deb | dpkg -x - /opt/gcc-9.3 \
    && curl -sL https://launchpad.net/~ubuntu-toolchain-r/+archive/ubuntu/ppa/+build/19784872/+files/libgcc-9-dev_9.3.0-17ubuntu1~20.04_amd64.deb | dpkg -x - /opt/gcc-9.3

RUN printf '#!/bin/sh\nexec /opt/gcc-9.3/usr/bin/gcc-9 -B/opt/gcc-9.3/usr/lib/gcc/x86_64-linux-gnu/9/ -I/opt/gcc-9.3/usr/lib/gcc/x86_64-linux-gnu/9/include "$@"\n' > /usr/local/bin/gcc-9.3 \
    && chmod +x /usr/local/bin/gcc-9.3

# Install official Rust 1.48.0
RUN curl -sL https://static.rust-lang.org/dist/rust-1.48.0-x86_64-unknown-linux-gnu.tar.gz | tar xz \
    && ./rust-1.48.0-x86_64-unknown-linux-gnu/install.sh --prefix=/usr/local \
    && rm -rf rust-1.48.0-x86_64-unknown-linux-gnu

# Create builder user scy
RUN useradd -m -u 1000 -s /bin/bash scy

# Setup source directory
COPY libbwt-jni /build
COPY bwt /build/bwt

# Add proxy feature to Cargo.toml
RUN sed -i '/signal-hook =/a proxy = [ "bwt/proxy" ]' /build/Cargo.toml

# Pin specific crate versions in Cargo.lock
RUN cat << "EOF" >> /build/Cargo.lock

[[package]]
name = "socks"
version = "0.3.3"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "30f86c7635fadf2814201a4f67efefb0007588ae7422ce299f354ab5c97f61ae"
dependencies = [
 "byteorder",
 "libc",
 "winapi 0.2.8",
 "ws2_32-sys",
]

[[package]]
name = "miniscript"
version = "6.0.1"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "d69450033bf162edf854d4aacaff82ca5ef34fa81f6cf69e1c81a103f0834997"
dependencies = [
 "bitcoin",
 "serde",
]

[[package]]
name = "jsonrpc"
version = "0.12.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "ad24d69a8a0698db8ffb9048e937e8ae3ee3bc45772a5d7b6979b1d2d5b6a9f7"
dependencies = [
 "base64-compat",
 "serde",
 "serde_derive",
 "serde_json",
]
EOF

# Pre-populate cargo cache so the build can run completely offline
ENV HOME=/home/scy
ENV CARGO_HOME=/home/scy/.cargo
ENV CC=gcc-9.3

RUN cd /build && \
    cargo build --release --no-default-features --features electrum,pretty_env_logger,proxy && \
    cargo clean

COPY reproduce.sh /build/reproduce.sh
RUN chmod +x /build/reproduce.sh && ln -s /build/reproduce.sh /reproduce.sh

WORKDIR /build
VOLUME ["/output"]
ENTRYPOINT ["./reproduce.sh"]
