# Releasing New Version

---

## 🚀 Quick Overview

1. Bump version in ``cmakelists``
2. Build new ``runtime`` and `installer`
3. Make sure `installer` is in `/utils` and `server.js` in `/utils/windows`
4. Run ``build/build_checksums.js`` this will generate `version.json` and `version-details.json` needed for the auto updater
```
node build_checksums.js <OpenSSL_Bin> <Git_Tag> <Shell_Version> <Server.js_Version>
node build_checksums.js "C:\Program Files\OpenSSL-Win64\bin" "5.0.0-beta.1" "5.0.0" v4.20.8
```
> **⏳Note:** Only Windows at the moment

5. Commit Changes
6. Make new release with the Git tag used when running ``build_checksums.js``

> **⏳Note:** Alternatively u can separate the version bump commit. Instead:
> Commit - Release - Build Checksums - Commit Built Checksums