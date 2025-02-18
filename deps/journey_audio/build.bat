echo off
mkdir build
pushd build
rem Debug build -g
echo "############################################## Clang Tidy "##############################################
clang-tidy ../library.h -checks=clang-analyzer-*,performace-*,portability-* --
echo "############################################## Clang Build "##############################################
clang-cl -c -g -Weverything -Wno-stack-protector -o journey_audio.lib ../library.c 
xcopy .\ ..\..\..\journey /y 
popd

start cmd /C "cd ../../ && odin run main.odin -file -debug"