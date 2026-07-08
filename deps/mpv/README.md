# libmpv

libmpv is **not** vendored in this repository. CMake downloads a pinned prebuilt
build from [mpv-player-windows on SourceForge](https://sourceforge.net/projects/mpv-player-windows/files/libmpv/)
at configure time, unpacks the DLL + headers into the build tree, and generates
an MSVC import library. See the `libmpv` block in the top-level `CMakeLists.txt`.

## Updating mpv

1. Pick a build from the SourceForge `libmpv` folder.
2. In `CMakeLists.txt`, set `MPV_VERSION` (e.g. `20260607-git-71ebd08`) and update
   the `MPV_ARCHIVE_SHA256` values for the x86_64 and i686 archives.
3. Re-run CMake. The new DLL, headers and `mpv.lib` are regenerated automatically.

## `libmpv.def`

The prebuilt archive ships a MinGW import library (`libmpv.dll.a`) that MSVC's
linker cannot consume. `libmpv.def` is the module-definition file listing the
exported `mpv_*` symbols; CMake runs `lib.exe /def:libmpv.def` to produce the
MSVC `mpv.lib`. The export set is stable across mpv releases, but if a future
build adds symbols you need, regenerate it with:

```cmd
dumpbin /exports libmpv-2.dll
```

and add the new `mpv_*` names under `EXPORTS`.
