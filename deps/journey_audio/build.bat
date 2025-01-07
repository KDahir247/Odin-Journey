mkdir build
pushd build

clang -c -Weverything -o journey_audio.lib ../library.c

popd