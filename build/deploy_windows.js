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
const readline = require('readline');

// ---------------------------------------------------------------------
// Project/Layout Configuration
// ---------------------------------------------------------------------
const SOURCE_DIR = path.resolve(__dirname, '..');
const BUILD_DIR = path.join(SOURCE_DIR, 'cmake-build-release');
const DIST_DIR = path.join(SOURCE_DIR, 'dist', 'win');
const PROJECT_NAME = 'stremio';

// Paths to Additional Dependencies
const MPV_DLL = path.join(SOURCE_DIR, 'deps', 'libmpv', 'x86_64', 'libmpv-2.dll');
const SERVER_JS = path.join(SOURCE_DIR, 'utils', 'windows', 'server.js');
const NODE_EXE = path.join(SOURCE_DIR, 'utils', 'windows', 'node.exe');
const DS_FOLDER = path.join(SOURCE_DIR, 'utils', 'windows', 'DS');
const STREMIO_RUNTIME_EXE = path.join(SOURCE_DIR, 'utils', 'windows', 'stremio-runtime.exe');
const FFMPEG_FOLDER = path.join(SOURCE_DIR, 'utils', 'windows', 'ffmpeg');
const MPV_FOLDER = path.join(SOURCE_DIR, 'utils', 'mpv');

// Default Paths
const DEFAULT_OPENSSL_BIN = 'C:\\Program Files\\OpenSSL-Win64\\bin';
const DEFAULT_QT_BIN = 'C:\\Qt\\6.8.1\\msvc2022_64\\bin';
const DEFAULT_NSIS = 'C:\\Program Files (x86)\\NSIS\\makensis.exe';

// ---------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------
(async function main() {
    try {
        const args = process.argv.slice(2);
        const buildInstaller = args.includes('--installer');

        // 1) Check or ask for OpenSSL path
        let sslBinDir = DEFAULT_OPENSSL_BIN;
        if (!fs.existsSync(sslBinDir)) {
            console.log(`Default OpenSSL bin not found at: ${sslBinDir}`);
            sslBinDir = await askQuestion(
                'Enter path to OpenSSL bin (e.g., C:\\Program Files\\OpenSSL-Win64\\bin): '
            );
            if (!fs.existsSync(sslBinDir)) {
                console.error(`Error: No valid OpenSSL bin dir at: ${sslBinDir}`);
                process.exit(1);
            }
        }
        console.log(`Using OpenSSL bin: ${sslBinDir}\n`);

        // 2) Locate windeployqt.exe
        let windeployqtPath = findInPath('windeployqt.exe');
        if (!windeployqtPath) {
            const defaultWindeployqt = path.join(DEFAULT_QT_BIN, 'windeployqt.exe');
            if (fs.existsSync(defaultWindeployqt)) {
                windeployqtPath = defaultWindeployqt;
                console.log(`Found windeployqt.exe at default path: ${windeployqtPath}`);
            } else {
                const promptQtBin = await askQuestion(
                    'Enter path to Qt bin (e.g. C:\\Qt\\6.8.1\\msvc2022_64\\bin): '
                );
                const possibleQtExe = path.join(promptQtBin, 'windeployqt.exe');
                if (!fs.existsSync(possibleQtExe)) {
                    console.error('Error: windeployqt.exe not found at that location.');
                    process.exit(1);
                }
                windeployqtPath = possibleQtExe;
            }
        } else {
            console.log(`Found windeployqt.exe in PATH: ${windeployqtPath}`);
        }

        // 3) Run CMake + Ninja in ../cmake-build-release (64-bit)
        if (!fs.existsSync(BUILD_DIR)) {
            fs.mkdirSync(BUILD_DIR, { recursive: true });
        }
        console.log('\n=== Running CMake in cmake-build-release ===');
        process.chdir(BUILD_DIR);
        execSync(`cmake -G Ninja -DCMAKE_BUILD_TYPE=Release ..`, { stdio: 'inherit' });

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
        copyFile(NODE_EXE, path.join(DIST_DIR, 'node.exe'));

        // 7) Copy OpenSSL DLLs
        console.log('Copying OpenSSL DLLs...');
        const dllList = ['libcrypto-3-x64.dll', 'libssl-3-x64.dll'];
        for (const dll of dllList) {
            copyFile(path.join(sslBinDir, dll), path.join(DIST_DIR, dll));
        }

        // 8) Flatten DS folder, stremio-runtime, ffmpeg
        console.log('Flattening DS folder, stremio-runtime, ffmpeg...');
        copyFolderContents(DS_FOLDER, DIST_DIR);
        copyFile(STREMIO_RUNTIME_EXE, path.join(DIST_DIR, 'stremio-runtime.exe'));
        copyFolderContents(FFMPEG_FOLDER, DIST_DIR);
        copyFolderContentsPreservingStructure(MPV_FOLDER, DIST_DIR);

        // 9) Run windeployqt.exe
        console.log('\n=== Deploying Qt dependencies ===');
        execSync(`"${windeployqtPath}" --qmldir "${SOURCE_DIR}" "${distExe}"`, { stdio: 'inherit' });

        console.log('\n=== dist\\win preparation complete. ===');

        // 10) If --installer, parse version and build NSIS
        if (buildInstaller) {
            console.log('\n--installer detected: building NSIS installer...');
            // Extract the version first so we can set process.env before calling NSIS
            const version = getPackageVersionFromCMake();
            process.env.package_version = version;
            console.log(`Set package_version to: ${version}`);
            buildNsisInstaller();
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

function askQuestion(prompt) {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    return new Promise(resolve => {
        rl.question(prompt, answer => {
            rl.close();
            resolve(answer.trim());
        });
    });
}

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
            // Copy files
            copyFile(srcItem, destItem);
        }
    }
}

/**
 * Attempt to find an executable in PATH on Windows.
 */
function findInPath(executable) {
    try {
        const result = execSync(`where ${executable}`, { stdio: ['pipe', 'pipe', 'ignore'] });
        return result.toString().split(/\r?\n/)[0].trim();
    } catch {
        return null;
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
        const nsiScript = path.join(SOURCE_DIR, 'utils', 'windows', 'installer', 'windows-installer.nsi');
        console.log(`Running makensis.exe with version: ${process.env.package_version} ...`);
        execSync(`"${DEFAULT_NSIS}" "${nsiScript}"`, { stdio: 'inherit' });
        console.log(`\nInstaller created: "Stremio ${process.env.package_version}.exe"`);
    } catch (err) {
        console.error('Failed to run NSIS (makensis.exe):', err);
    }
}