#!/usr/bin/env node

/****************************************************************************
 * deploy_windows.js
 *
 * Builds windows distributable folder dist/win.
 * Pass --installer to also build the windows installer
 * Make sure to have set up utils/windows and the environment correctly by following windows.md
 *
 ****************************************************************************/

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// ---------------------------------------------------------------------
// Project/Layout Configuration
// ---------------------------------------------------------------------
const ARCH = process.argv.includes('--x86') ? 'x86' : 'x64';
const SOURCE_DIR = path.resolve(__dirname, '..');
const BUILD_DIR = path.join(SOURCE_DIR, `cmake-build-release-${ARCH}`);
const DIST_DIR = path.join(SOURCE_DIR, 'dist', `win-${ARCH}`);
const CONFIG_DIR = path.join(SOURCE_DIR, 'dist', `win-${ARCH}`, 'portable_config');
const PROJECT_NAME = 'stremio';

// Paths to Additional Dependencies
// libmpv is downloaded and unpacked into the build tree by CMake (see the
// libmpv block in CMakeLists.txt), so the DLL lives under the build dir now.
const MPV_ARCH = ARCH === 'x86' ? 'i686' : 'x86_64';
const MPV_DLL = path.join(BUILD_DIR, 'libmpv', MPV_ARCH, 'libmpv-2.dll');
const SERVER_JS = path.join(SOURCE_DIR, 'utils', 'windows', 'server.js');
const STREMIO_RUNTIME_EXE = path.join(SOURCE_DIR, 'utils', 'windows', 'stremio-runtime.exe');
const FFMPEG_FOLDER = path.join(SOURCE_DIR, 'utils', 'windows', 'ffmpeg');
const MPV_FOLDER = path.join(SOURCE_DIR, 'utils', 'mpv', 'anime4k');
const DEFAULT_SETTINGS_FOLDER = path.join(SOURCE_DIR, 'utils', 'stremio');

// Default Paths
const DEFAULT_NSIS = 'C:\\Program Files (x86)\\NSIS\\makensis.exe';
//VCPKG
const VCPKG_TRIPLET = ARCH === 'x86' ? 'x86-windows-static' : 'x64-windows-static';
const VCPKG_CMAKE = 'G:\\Documents\\Github\\vcpkg\\scripts\\buildsystems\\vcpkg.cmake';

// ---------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------
(async function main() {
    try {
        console.log(`\n=== Building for ${ARCH.toUpperCase()} ===`);
        const args = process.argv.slice(2);
        const buildInstaller = args.includes('--installer');
        const buildPortable = args.includes('--portable');
        const debugBuild = args.includes('--debug');

        // 3) Run CMake + Ninja in ../cmake-build-release (64-bit)
        if (!fs.existsSync(BUILD_DIR)) {
            fs.mkdirSync(BUILD_DIR, { recursive: true });
        }

        console.log(`\n=== Running CMake in cmake-build-${debugBuild ? "Debug" : "Release"} ===`);
        process.chdir(BUILD_DIR);
        execSync(
            `cmake -G Ninja -DCMAKE_BUILD_TYPE=${debugBuild ? "Debug" : "Release"} -DCMAKE_TOOLCHAIN_FILE=${VCPKG_CMAKE} -DVCPKG_TARGET_TRIPLET=${VCPKG_TRIPLET} ..`,
            { stdio: 'inherit' }
        );
        console.log('=== Running Ninja in cmake-build-release ===');
        execSync('ninja', { stdio: 'inherit' });

        // Return to script directory
        process.chdir(__dirname);

        // 4) Prepare dist\win
        console.log(`\n=== Cleaning and creating ${DIST_DIR} ===`);
        safeRemove(DIST_DIR);
        fs.mkdirSync(DIST_DIR, { recursive: true });

        // 5) Copy main .exe
        const builtExe = path.join(BUILD_DIR, `${PROJECT_NAME}.exe`);
        const distExe = path.join(DIST_DIR, `${PROJECT_NAME}.exe`);
        copyFile(builtExe, distExe);

        // 6) Copy mpv DLL, server.js, node.exe
        copyFile(MPV_DLL, path.join(DIST_DIR, path.basename(MPV_DLL)));
        copyFile(SERVER_JS, path.join(DIST_DIR, path.basename(SERVER_JS)));




        // 8) Flatten stremio-runtime, ffmpeg
        console.log('Flattening DS folder, stremio-runtime, ffmpeg...');
        copyFile(STREMIO_RUNTIME_EXE, path.join(DIST_DIR, 'stremio-runtime.exe'));
        copyFolderContents(FFMPEG_FOLDER, DIST_DIR);
        copyFolderContentsPreservingStructure(MPV_FOLDER, DIST_DIR);
        copyFolderContentsPreservingStructure(DEFAULT_SETTINGS_FOLDER, CONFIG_DIR);

        console.log('\n=== dist\\win preparation complete. ===');

        // 10) If --installer, parse version and build NSIS
        if (buildInstaller) {
            console.log('\n--installer detected: building NSIS installer...');
            // Extract the version first so we can set process.env before calling NSIS
            const version = getPackageVersionFromCMake();
            process.env.package_version = version;
            console.log(`Set package_version to: ${version}`);
            buildNsisInstaller();
        } else if (buildPortable) {
            console.log('\n--portable detected: building Portable...');
            buildPortableZip();
        }


        console.log('\nAll done!');
    } catch (err) {
        console.error('Error in deploy_windows.js:', err);
        process.exit(1);
    }
})();

/****************************************************************************
 * Helper Functions
 ****************************************************************************/

function safeRemove(dirPath) {
    if (fs.existsSync(dirPath)) {
        fs.rmSync(dirPath, { recursive: true, force: true });
    }
}

function copyFile(src, dest) {
    if (!fs.existsSync(src)) {
        console.warn(`Warning: missing file: ${src}`);
        return;
    }
    fs.copyFileSync(src, dest);
    console.log(`Copied: ${src} -> ${dest}`);
}

/**
 * Recursively copies only the contents of "src" into "dest" (flattened).
 * If src has files/folders, they go directly into dest, rather than
 * creating a subfolder named src.
 */
function copyFolderContents(src, dest) {
    if (!fs.existsSync(src)) {
        console.warn(`Warning: missing folder: ${src}`);
        return;
    }
    const stats = fs.statSync(src);
    if (!stats.isDirectory()) {
        console.warn(`Warning: not a directory: ${src}`);
        return;
    }
    for (const item of fs.readdirSync(src)) {
        const srcItem = path.join(src, item);
        const itemStats = fs.statSync(srcItem);
        const destItem = path.join(dest, item);
        if (itemStats.isDirectory()) {
            copyFolderContents(srcItem, dest);
        } else {
            copyFile(srcItem, destItem);
        }
    }
}

/**
 * Copies the contents of `src` into `dest` without flattening.
 * Subdirectories in `src` will be recreated in `dest`.
 */
function copyFolderContentsPreservingStructure(src, dest) {
    if (!fs.existsSync(src)) {
        console.warn(`Warning: missing folder: ${src}`);
        return;
    }

    const stats = fs.statSync(src);
    if (!stats.isDirectory()) {
        console.warn(`Warning: not a directory: ${src}`);
        return;
    }

    // Ensure destination directory exists
    if (!fs.existsSync(dest)) {
        fs.mkdirSync(dest, { recursive: true });
    }

    const items = fs.readdirSync(src);

    for (const item of items) {
        const srcItem = path.join(src, item);
        const destItem = path.join(dest, item);
        const itemStats = fs.statSync(srcItem);

        if (itemStats.isDirectory()) {
            // Recursively copy subdirectories
            copyFolderContentsPreservingStructure(srcItem, destItem);
        } else {
            if (!srcItem.endsWith('zip') && !srcItem.endsWith('7z')) {
                // Copy files
                copyFile(srcItem, destItem);
            }
        }
    }
}

/**
 * Retrieves version from CMakeLists.txt (handles quotes):
 *  project(stremio VERSION "5.0.2")
 */
function getPackageVersionFromCMake() {
    const cmakeFile = path.join(SOURCE_DIR, 'CMakeLists.txt');
    let version = '0.0.0';
    if (fs.existsSync(cmakeFile)) {
        const content = fs.readFileSync(cmakeFile, 'utf8');
        // Accept either quoted or unquoted numerical version
        const match = content.match(/project\s*\(\s*stremio\s+VERSION\s+"?([\d.]+)"?\)/i);
        if (match) {
            version = match[1];
        }
    }
    return version;
}

function buildNsisInstaller() {
    if (!fs.existsSync(DEFAULT_NSIS)) {
        console.warn(`NSIS not found at default path: ${DEFAULT_NSIS}. Skipping installer.`);
        return;
    }
    try {
        const arch = process.argv.includes('--x86') ? 'x86' : 'x64'; // Determine architecture
        const distSubfolder = `win-${arch}`;

        const distFolder = path.join(SOURCE_DIR, 'dist', distSubfolder);
        if (!fs.existsSync(distFolder)) {
            console.error(`Error: Distribution folder does not exist: ${distFolder}`);
            process.exit(1);
        }


        const nsiScript = path.join(SOURCE_DIR, 'utils', 'windows', 'installer', 'windows-installer.nsi');
        console.log(`Running makensis.exe with version: ${process.env.package_version} ...`);
        process.env.arch = arch;
        execSync(`"${DEFAULT_NSIS}" "${nsiScript}"`, { stdio: 'inherit' });
        console.log(`\nInstaller created: "Stremio ${process.env.package_version}.exe"`);
    } catch (err) {
        console.error('Failed to run NSIS (makensis.exe):', err);
    }
}

function buildPortableZip() {
    const version = getPackageVersionFromCMake();
    const portableOutput = path.join(SOURCE_DIR, 'utils', `Stremio ${version}-${ARCH}.7z`);
    const fixedEdgeWebView = path.join(SOURCE_DIR, 'utils', 'windows', 'WebviewRuntime', ARCH);
    const portable_config = path.join(DIST_DIR, 'portable_config');
    const distContents = DIST_DIR; // Path to dist directory contents

    console.log(`\nCreating Portable ZIP: ${portableOutput}`);

    // Common 7-Zip paths
    const common7zPaths = [
        'C:\\Program Files\\7-Zip\\7z.exe',
        'C:\\Program Files (x86)\\7-Zip\\7z.exe'
    ];

    // Find 7-Zip executable
    const sevenZipPath = common7zPaths.find(fs.existsSync);
    if (!sevenZipPath) {
        console.error('Error: 7-Zip executable not found in common paths.');
        console.error('Please install 7-Zip and ensure it is in one of the following paths:');
        console.error(common7zPaths.join('\n'));
        process.exit(1);
    }

    console.log(`Using 7-Zip at: ${sevenZipPath}`);

    // Ensure the DIST_DIR exists
    if (!fs.existsSync(DIST_DIR)) {
        console.error(`Error: DIST_DIR does not exist: ${DIST_DIR}`);
        process.exit(1);
    }

    copyFolderContentsPreservingStructure(fixedEdgeWebView, portable_config);

    // Command to create the 7z archive
    const zipCommand = `"${sevenZipPath}" a -t7z -mx=9 "${portableOutput}" "${distContents}\\*"`;

    try {
        // Run the 7-Zip command
        console.log(`Running: ${zipCommand}`);
        execSync(zipCommand, { stdio: 'inherit' });
        console.log(`\nPortable ZIP created: ${portableOutput}`);
        //Clean UP
        const portableConfigWebView = path.join(DIST_DIR, 'portable_config', 'EdgeWebView');
        if (fs.existsSync(portableConfigWebView)) {
            console.log(`\nCleaning up: ${portableConfigWebView}`);
            fs.rmSync(portableConfigWebView, { recursive: true, force: true });
            console.log(`Removed: ${portableConfigWebView}`);
        } else {
            console.log(`\nNo cleanup needed: ${portableConfigWebView} does not exist.`);
        }
    } catch (error) {
        console.error('Error creating the Portable ZIP:', error);
        process.exit(1);
    }
}