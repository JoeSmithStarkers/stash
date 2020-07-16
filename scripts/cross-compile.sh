#!/bin/sh

BUILD_DATE=`go run -mod=vendor scripts/getDate.go`
GITHASH=`git rev-parse --short HEAD`
STASH_VERSION=`git describe --tags --exclude latest_develop`

SETENV="BUILD_DATE=\"$BUILD_DATE\" GITHASH=$GITHASH STASH_VERSION=\"$STASH_VERSION\""
SETUP="export GO111MODULE=on; export CGO_ENABLED=1; make packr;"
SETUP_FAST="export GO111MODULE=on; export CGO_ENABLED=1;"
WINDOWS="echo '=== Building Windows binary ==='; $SETENV GOOS=windows GOARCH=amd64 CC=x86_64-w64-mingw32-gcc CXX=x86_64-w64-mingw32-g++ LDFLAGS=\"-extldflags '-static' \" OUTPUT=\"dist/stash-win.exe\" make build-release;"
DARWIN="echo '=== Building OSX binary ==='; $SETENV GOOS=darwin GOARCH=amd64 CC=o64-clang CXX=o64-clang++ OUTPUT=\"dist/stash-osx\" make build-release;"
LINUX="echo '=== Building Linux binary ==='; $SETENV OUTPUT=\"dist/stash-linux\" make build-release;"
RASPPI="echo '=== Building Raspberry Pi binary ==='; $SETENV GOOS=linux GOARCH=arm GOARM=5 CC=arm-linux-gnueabi-gcc OUTPUT=\"dist/stash-pi\" make build-release;"

# if build target ends with -fast then use prebuilt packr2. eg linux-fast or all-fast
if [ `echo "$1" | cut -d - -f 2` == "fast" ]
then
  echo "Building without Packr2"
  SETUP=$SETUP_FAST
fi

BUILD=`echo "$1" | cut -d - -f 1`
if [ "$BUILD" == "windows" ]
then
  echo "Building Windows"
  COMMAND="$SETUP $WINDOWS"
elif [ "$BUILD" == "darwin" ]
then
  echo "Building Darwin(MacOSX)"
  COMMAND="$SETUP $DARWIN"
elif [ "$BUILD" == "linux" ]
then
  echo "Building Linux"
  COMMAND="$SETUP $LINUX"
elif [ "$BUILD" == "rpi" ]
then
  echo "Building RaspberryPi"
  COMMAND="$SETUP $RASPPI"
else
  echo "Building All"
  COMMAND="$SETUP $WINDOWS $DARWIN $LINUX $RASPPI"
fi

# Changed consistency to delegated since this is being used as a build tool. The binded volume shouldn't be changing during its run.
docker run --rm --mount type=bind,source="$(pwd)",target=/stash,consistency=delegated -w /stash stashapp/compiler:develop /bin/bash -c "$COMMAND"
