#!/bin/bash
# uSockets compilation script
# Used to recompile libusockets_full.a (including uSockets + libuv)
# Support: Windows (Git Bash/MSYS2), macOS (Intel/Apple Silicon), Linux
#Output to: usockets/lib/{platform}/libusockets_full.a

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USOCKETS_DIR="/tmp/uSockets"
LIBUV_DIR="/tmp/libuv"
MERGE_DIR="/tmp/merge_libs"

echo "=== uSockets 编译脚本 ==="
echo "检测到系统: $OSTYPE"

# Determine the output directory
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ $(uname -m) == "arm64" ]]; then
        OUTPUT_DIR="$SCRIPT_DIR/lib/macos-arm64"
    else
        OUTPUT_DIR="$SCRIPT_DIR/lib/macos-x64"
    fi
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "mingw"* ]]; then
    OUTPUT_DIR="$SCRIPT_DIR/lib/windows"
elif [[ "$OSTYPE" == "linux"* ]]; then
    OUTPUT_DIR="$SCRIPT_DIR/lib/linux"
else
    OUTPUT_DIR="$SCRIPT_DIR/lib/linux"
fi

echo "输出目录: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Check if there is uSockets source code
if [ ! -d "$USOCKETS_DIR" ]; then
    echo "克隆 uSockets..."
    git clone --depth 1 https://github.com/uNetworking/uSockets.git "$USOCKETS_DIR"
fi

# Check if there is libuv source code
if [ ! -d "$LIBUV_DIR" ]; then
    echo "克隆 libuv..."
    git clone --depth 1 --branch v1.48.0 https://github.com/libuv/libuv.git "$LIBUV_DIR"
fi

# Apply backlog modifications
echo "应用 backlog=16384 修改..."
if [ -f "$SCRIPT_DIR/src/bsd.c" ]; then
    cp "$SCRIPT_DIR/src/bsd.c" "$USOCKETS_DIR/src/bsd.c"
else
    sed -i.bak 's/listen(listenFd, 512)/listen(listenFd, 16384)/g' "$USOCKETS_DIR/src/bsd.c"
fi

# Compile libuv
compile_libuv() {
    echo "编译 libuv..."
    cd "$LIBUV_DIR"
    rm -rf build 2>/dev/null || true
    mkdir -p build
    cd build
    
    if ! command -v cmake &> /dev/null; then
        echo "错误: 需要安装 cmake"
        echo "  macOS: brew install cmake"
        echo "  Linux: sudo apt install cmake 或 sudo yum install cmake"
        echo "  Windows: scoop install cmake 或 choco install cmake"
        exit 1
    fi
    
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "mingw"* ]]; then
        cmake .. -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DLIBUV_BUILD_SHARED=OFF
    else
        cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DLIBUV_BUILD_SHARED=OFF
    fi
    
    cmake --build . --config Release
}

# Compile uSockets
compile_usockets() {
    echo "编译 uSockets..."
    cd "$USOCKETS_DIR"
    rm -f *.o *.a 2>/dev/null || true
    
    gcc -DLIBUS_NO_SSL -DLIBUS_USE_LIBUV -std=c11 -Isrc -I"$LIBUV_DIR/include" -O3 -c src/*.c src/eventing/*.c src/crypto/*.c
    ar rcs uSockets.a *.o
    rm -f *.o
}

# Merge library files
merge_libraries() {
echo "Merge library files..."
    rm -rf "$MERGE_DIR"
    mkdir -p "$MERGE_DIR"
    
    cd "$MERGE_DIR"
    ar x "$USOCKETS_DIR/uSockets.a"
    ar x "$LIBUV_DIR/build/libuv.a"
    
    ar rcs "$OUTPUT_DIR/libusockets_full.a" *.o
    
    rm -rf "$MERGE_DIR"
}

# Execute compilation
compile_libuv
compile_usockets
merge_libraries

# show results
LIB_SIZE=$(ls -lh "$OUTPUT_DIR/libusockets_full.a" | awk '{print $5}')
echo ""
echo "=== Compilation completed ==="
echo "Library file: $OUTPUT_DIR/libusockets_full.a ($LIB_SIZE)"
echo ""
echo "Compile vono application:"
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "mingw"* ]]; then
    echo "  v -enable-globals -cc gcc -ldflags \"-ldbghelp\" -o app.exe app.v"
else
    echo "  v -enable-globals -prod -o app app.v"
fi
