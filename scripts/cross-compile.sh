#!/bin/sh

# "stashapp/compiler:develop" "stashapp/compiler:4"
COMPILER_CONTAINER="stashapp/compiler:4"

BUILD_DATE=`go run -mod=vendor scripts/getDate.go`
GITHASH=`git rev-parse --short HEAD`
STASH_VERSION=`git describe --tags --exclude latest_develop`

SETENV="BUILD_DATE=\"$BUILD_DATE\" GITHASH=$GITHASH STASH_VERSION=\"$STASH_VERSION\""
SETUP="export GO111MODULE=on; export CGO_ENABLED=1; set -e; echo '=== Running packr ==='; make packr;"
SETUP_FAST="export GO111MODULE=on; export CGO_ENABLED=1;"
WINDOWS="echo '=== Building Windows binary ==='; $SETENV GOOS=windows GOARCH=amd64 CC=x86_64-w64-mingw32-gcc CXX=x86_64-w64-mingw32-g++ LDFLAGS=\"-extldflags '-static' \" OUTPUT=\"dist/stash-win.exe\" make build-release;"
DARWIN="echo '=== Building OSX binary ==='; $SETENV GOOS=darwin GOARCH=amd64 CC=o64-clang CXX=o64-clang++ OUTPUT=\"dist/stash-osx\" make build-release;"
LINUX_AMD64="echo '=== Building Linux (amd64) binary ==='; $SETENV GOOS=linux GOARCH=amd64 OUTPUT=\"dist/stash-linux\" make build-release-static;"
LINUX_ARM64v8="echo '=== Building Linux (armv8/arm64) binary ==='; $SETENV GOOS=linux GOARCH=arm64 CC=aarch64-linux-gnu-gcc OUTPUT=\"dist/stash-linux-arm64v8\" make build-release-static;"
LINUX_ARM32v7="echo '=== Building Linux (armv7/armhf) binary ==='; $SETENV GOOS=linux GOARCH=arm GOARM=7 CC=arm-linux-gnueabihf-gcc OUTPUT=\"dist/stash-linux-arm32v7\" make build-release-static;"
LINUX_ARM32v6="echo '=== Building Linux (armv6 | Raspberry Pi 1) binary ==='; $SETENV GOOS=linux GOARCH=arm GOARM=6 CC=arm-linux-gnueabi-gcc OUTPUT=\"dist/stash-pi\" make build-release-static;"
BUILD_COMPLETE="echo '=== Build complete ==='"

# if build target ends with -fast then use prebuilt packr2. eg amd64-fast or all-fast
FAST=`echo "$1" | cut -d - -f 2`
if [ "$FAST" == "fast" ]
then
  echo "Building without Packr2"
  SETUP=$SETUP_FAST
fi

BUILD=`echo "$1" | cut -d - -f 1`
if [ "$BUILD" == "windows" ]
then
  echo "Building Windows"
  COMMAND="$SETUP $WINDOWS $BUILD_COMPLETE"
elif [ "$BUILD" == "darwin" ]
then
  echo "Building Darwin(MacOSX)"
  COMMAND="$SETUP $DARWIN $BUILD_COMPLETE"
elif [ "$BUILD" == "amd64" ]
then
  echo "Building Linux AMD64"
  COMMAND="$SETUP $LINUX_AMD64 $BUILD_COMPLETE"
elif [ "$BUILD" == "arm64v8" ]
then
  echo "Building Linux ARM64v8"
  COMMAND="$SETUP $LINUX_ARM64v8 $BUILD_COMPLETE"
elif [ "$BUILD" == "arm32v6" ]
then
  echo "Building Linux ARM32v6"
  COMMAND="$SETUP $LINUX_ARM32v6 $BUILD_COMPLETE"
elif [ "$BUILD" == "arm32v7" ]
then
  echo "Building Linux ARM32v7"
  COMMAND="$SETUP $LINUX_ARM32v7 $BUILD_COMPLETE"
else
  echo "Building All"
  COMMAND="$SETUP $WINDOWS $DARWIN $LINUX_AMD64 $LINUX_ARM64v8 $LINUX_ARM32v7 $LINUX_ARM32v6 $BUILD_COMPLETE"
fi

# Pull Latest Image
docker pull $COMPILER_CONTAINER

# Changed consistency to delegated since this is being used as a build tool. The binded volume shouldn't be changing during its run.
docker run --rm --mount type=bind,source="$(pwd)",target=/stash,consistency=delegated -w /stash $COMPILER_CONTAINER /bin/bash -c "$COMMAND"

