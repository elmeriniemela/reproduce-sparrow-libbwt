# Reproducing Sparrow's `libbwt_jni.so`

Exact, bit-for-bit reproduction of Sparrow Wallet's `libbwt_jni.so` (Linux x86_64) from source using `podman`.

## Target Binary & Checksum

- **File**: `libbwt_jni.so`
- **Origin**: Native library bundled in Sparrow Wallet ([commit `58cd50f`](https://github.com/sparrowwallet/sparrow/commit/58cd50f67455cb5fd6845ec848f809b21f855c52))
- **Expected SHA-256**:
  ```text
  49ea61c9cde78fe7de322cba3b5e0d0b06bbc6c41fb4c40fbc59e986479f0e16
  ```

---

## Instructions

### Prerequisites

- `podman` (or `docker`)

### Build the Container Image

Build the reproducible build image using `Containerfile`:

```bash
podman build -t reproduce-sparrow .
```

During the image build:
- Ubuntu 20.04 base packages and official Rust 1.48.0 toolchain are installed.
- Required GCC packages (`9.4.0-1ubuntu1~20.04.1` and `9.3.0-17ubuntu1~20.04`) are installed/configured.
- Dependencies are pre-cached under `/home/scy/.cargo` so the runtime build runs completely offline.

### Run the Reproduction Build

Execute `reproduce.sh` inside the container by mounting an output directory:

```bash
podman run --rm -v "$(pwd)/out:/output" reproduce-sparrow
```

This compiles the binary offline and writes `reproduced_libbwt_jni.so` to `./out/`.

### Verify Exact Match

Compare the reproduced library with the original reference:

```bash
sha256sum out/reproduced_libbwt_jni.so
```

---

## Technical Details & Provenance

### Source Code Provenance

- **`libbwt-jni`**: At commit [`6f945d4`](https://github.com/bwt-dev/libbwt-jni/commit/6f945d4d58418fbb36cea03940b7613940b619a0) (`v0.2.4`).
- **`bwt`**: At commit [`e1885d9`](https://github.com/bwt-dev/bwt/commit/e1885d97eb70c8f84db3383e7e2d04ad063f3ec0) (*"Prefer using fees.base for getrawmempool entries (#97)"*). This commit added Bitcoin Core v23 compatibility and SOCKS5h proxy support.
- **Cargo features**:
  - `libbwt-jni` exposes `proxy = [ "bwt/proxy" ]`.
  - Rust compilation flags:
    ```sh
    cargo build --offline --release --no-default-features \
      --features electrum,pretty_env_logger,proxy
    ```
- **Pinned dependencies in `Cargo.lock`**:
  - `socks = "0.3.3"`
  - `miniscript = "6.0.1"`
  - `jsonrpc = "0.12.0"`

```bash
git subtree add --prefix=libbwt-jni https://github.com/bwt-dev/libbwt-jni.git 6f945d4d58418fbb36cea03940b7613940b619a0 --squash
git subtree add --prefix=bwt https://github.com/bwt-dev/bwt e1885d97eb70c8f84db3383e7e2d04ad063f3ec0 --squash
```

### Toolchains & Environment

- **Rust**: Official archive Rust `1.48.0` (`7eac88abb 2020-11-16`).
- **Operating System**: Ubuntu 20.04 LTS.
- **Build User**: Username `scy` (`HOME=/home/scy`, `CARGO_HOME=/home/scy/.cargo`). In Rust 1.48, crate panic location strings embed `$CARGO_HOME/registry/src/github.com-1ecc6299db9ec823/...`.
- **Dual GCC Setup**:
  - `GCC 9.3.0-17ubuntu1~20.04`: Used as `CC` for C dependency compilation (`secp256k1-sys` compiling `secp256k1.c` and `lax_der_parsing.c`).
  - `GCC 9.4.0-1ubuntu1~20.04.1`: Used for CRT startup objects (`crtbeginS.o`) and final Rust linking.
  - This reproduces the exact `.comment` section of the original ELF binary:
    ```text
    GCC: (Ubuntu 9.4.0-1ubuntu1~20.04.1) 9.4.0
    GCC: (Ubuntu 9.3.0-17ubuntu1~20.04) 9.3.0
    ```
