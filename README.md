#### aim4zig

Simple game inspired by the (former) flash game [aimbooster](https://aimbooster.com)
Written in zig, using raylib, and [raylib-zig](https://github.com/Not-Nik/raylib-zig) bindings

Compiled to wasm with [emscripten](https://emscripten.org/)

##### Compile and run:

Make sure you have zig installed on your machine.

To run native:

```bash
zig build run
```

To compile for web, install and configure emsdk [see here](<https://github.com/raysan5/raylib/wiki/Working-for-Web-(HTML5)#1-install-emscripten-toolchain>)
Then run:

```bash
zig build -Dtarget=wasm32-emscripten --sysroot [path_to_emsdk_lib]/upstream/emscripten
```
