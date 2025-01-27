#!/usr/bin/env bash
# Copyright (c) Facebook, Inc. and its affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

set -ex

TARGET="$2"
PKG_DIR="${1%/}"/pkgs
INSTALL_DIR="${1%/}"/install
INSTALL_AUX_DIR="${1%/}"/install/aux

[ -n "$TARGET" ] || ( echo "Target missing"; exit 1 )

SYSTEM_MEM="$(free -g | grep "^Mem:" | tr -s '[:blank:]' | cut -d ' ' -f 2)"
if (( ${SYSTEM_MEM:-0} <= 25 )); then
    echo "mcrouter needs a lot of memory to compile, and is known to exhaust memory on 16gb systems." >&2
    echo "On EC2 consider an instance with 32 GB of memory, like an m6g.2xlarge or m5a.2xlarge" >&2
    exit 1
fi

mkdir -p "$PKG_DIR" "$INSTALL_DIR" "$INSTALL_AUX_DIR"
mkdir -p "$INSTALL_DIR/lib"

# The recipes/mcrouter.sh build script fails at convincing the compiler and linker
# to look at $INSTALL_DIR/lib64
# As a workaround, we just upfront link lib64 -> lib so all dependency artifacts
# end up in $INSTALL_DIR/lib which that build script *can* find.
if [ ! -e "$INSTALL_DIR/lib64" ]; then
    ln -sf lib "$INSTALL_DIR/lib64"
fi

cd "$(dirname "$0")" || ( echo "cd fail"; exit 1 )

REPO_BASE_DIR="$(cd ../../ && pwd)" || die "Couldn't determine repo top dir"
export REPO_BASE_DIR

export LDFLAGS="-L$INSTALL_DIR/lib -ljemalloc $LDFLAGS"
# Set CC and CXX to unambiguously choose compiler.
export CC=/usr/bin/gcc
export CXX=/usr/bin/c++

make "$TARGET" -j "$(nproc)" -f "Makefile_amazon-linux-2" PKG_DIR="$PKG_DIR" INSTALL_DIR="$INSTALL_DIR" INSTALL_AUX_DIR="$INSTALL_AUX_DIR"

printf "%s\n" "make $TARGET for $MAKE_FILE done"
