mkdir build
pushd build
rem Debug build -g
clang-cl -c -g -Og -Weverything -Wno-unsafe-buffer-usage -o journey_audio.lib ../library.c 
xcopy .\ ..\..\..\journey /y 
popd