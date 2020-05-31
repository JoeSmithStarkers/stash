#!/bin/sh

DATE=`go run -mod=vendor scripts/getDate.go`
GITHASH=`git rev-parse --short HEAD`
STASH_VERSION=`git describe --tags --exclude latest_develop`
VERSION_FLAGS="-X 'github.com/stashapp/stash/pkg/api.version=$STASH_VERSION' -X 'github.com/stashapp/stash/pkg/api.buildstamp=$DATE' -X 'github.com/stashapp/stash/pkg/api.githash=$GITHASH'"
SETUP="export GO111MODULE=on; export CGO_ENABLED=1; packr2;"
SETUP_FAST="export GO111MODULE=on; export CGO_ENABLED=1;"
WINDOWS="echo '=== Building Windows binary ==='; GOOS=windows GOARCH=amd64 CC=x86_64-w64-mingw32-gcc CXX=x86_64-w64-mingw32-g++ go build -o dist/stash-win.exe -ldflags \"-extldflags '-static' $VERSION_FLAGS\" -tags extended -v -mod=vendor;"
DARWIN="echo '=== Building OSX binary ==='; GOOS=darwin GOARCH=amd64 CC=o64-clang CXX=o64-clang++ go build -o dist/stash-osx -ldflags \"$VERSION_FLAGS\" -tags extended -v -mod=vendor;"
LINUX="echo '=== Building Linux binary ==='; go build -o dist/stash-linux -ldflags \"$VERSION_FLAGS\" -v -mod=vendor;"
RASPPI="echo '=== Building Raspberry Pi binary ==='; GOOS=linux GOARCH=arm GOARM=5 CC=arm-linux-gnueabi-gcc go build -o dist/stash-pi -ldflags \"$VERSION_FLAGS\" -v -mod=vendor;"

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
