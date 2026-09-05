#!/usr/bin/env bash
set -euxo pipefail

cd /build
export HOME=/home/scy
export CARGO_HOME=/home/scy/.cargo
export CC=gcc-9.3

cargo build --offline --release --no-default-features \
  --features electrum,pretty_env_logger,proxy

cp target/release/libbwt_jni.so /output/reproduced_libbwt_jni.so
sha256sum /output/reproduced_libbwt_jni.so
