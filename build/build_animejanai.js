#!/usr/bin/env node

/**
 * build_animejanai.js
 *
 * This script performs the following:
 * 1. Downloads the latest 'full-package' .7z release from Animejanai GitHub.
 * 2. Extracts the archive.
 * 3. Deletes specified files and folders.
 * 4. Modifies configuration files as per stremio requirements.
 * 5. Repackages the modified files into a new .7z archive with maximum compression.
 * 6. Places the final archive in utils/mpv.
 * 7. Cleans up temporary files.
 *
 * Usage:
 *   node build_animejanai.js
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const { execSync } = require('child_process');
const os = require('os');

// Configuration
const GITHUB_API_URL = 'https://api.github.com/repos/the-database/mpv-upscale-2x_animejanai/releases/latest';
const TEMP_DIR = path.join(os.tmpdir(), 'animejanai_build_temp');
const OUTPUT_DIR = path.resolve(__dirname, '..', 'utils', 'mpv');
const OUTPUT_FILENAME_TEMPLATE = 'stremio-animejanai-{version}.7z';

// Files and directories to delete
const FILES_TO_DELETE = [
    'libmpv-2.dll',
    'libmpvnet.pdb',
    'MediaInfo.dll',
    'mpvnet.com',
    'mpvnet.dll.config',
    'mpvnet.exe',
    'mpvnet.pdb',
    'NGettext.Wpf.pdb'
];

const FOLDERS_TO_DELETE = [
    'Locale'
];

// Configuration for input.conf replacement
const NEW_INPUT_CONF_CONTENT = `
Ctrl+E           show-text "Launching AnimeJaNaiConfEditor..."; run "~~\\..\\animejanai\\AnimeJaNaiConfEditor.exe" #menu: AnimeJaNai > Launch AnimeJaNaiConfEditor
Ctrl+J           script-binding "show_animejanai_stats" #menu: AnimeJaNai > Toggle AnimeJaNai Stats

)                show-text "2x_AnimeJaNai_V3 Off"; apply-profile upscale-off;
Ctrl+0           show-text "2x_AnimeJaNai_V3 Off"; apply-profile upscale-off;
SHIFT+1          show-text "2x_AnimeJaNai_V3 Quality"; apply-profile upscale-on-quality;
SHIFT+2          show-text "2x_AnimeJaNai_V3 Balanced"; apply-profile upscale-on-balanced;
SHIFT+3          show-text "2x_AnimeJaNai_V3 Performance"; apply-profile upscale-on-performance;
Ctrl+1           show-text "2x_AnimeJaNai_V3 Custom Profile 1"; apply-profile upscale-on-1;
Ctrl+2           show-text "2x_AnimeJaNai_V3 Custom Profile 2"; apply-profile upscale-on-2;
Ctrl+3           show-text "2x_AnimeJaNai_V3 Custom Profile 3"; apply-profile upscale-on-3;
Ctrl+4           show-text "2x_AnimeJaNai_V3 Custom Profile 4"; apply-profile upscale-on-4;
Ctrl+5           show-text "2x_AnimeJaNai_V3 Custom Profile 5"; apply-profile upscale-on-5;
Ctrl+6           show-text "2x_AnimeJaNai_V3 Custom Profile 6"; apply-profile upscale-on-6;
Ctrl+7           show-text "2x_AnimeJaNai_V3 Custom Profile 7"; apply-profile upscale-on-7;
Ctrl+8           show-text "2x_AnimeJaNai_V3 Custom Profile 8"; apply-profile upscale-on-8;
Ctrl+9           show-text "2x_AnimeJaNai_V3 Custom Profile 9"; apply-profile upscale-on-9;
`;

// Lines to delete from mpv.conf
const LINES_TO_DELETE_IN_MPV_CONF = [
    'save-position-on-quit=yes',
    'watch-later-options=start',
    'reset-on-next-file=pause'
];

// Common 7z.exe installation paths on Windows
const COMMON_7Z_PATHS = [
    path.join(process.env.PROGRAMFILES || 'C:\\Program Files', '7-Zip', '7z.exe'),
    path.join(process.env['PROGRAMFILES(X86)'] || 'C:\\Program Files (x86)', '7-Zip', '7z.exe'),
    path.join(process.env.LOCALAPPDATA || path.join(os.homedir(), 'AppData', 'Local'), '7-Zip', '7z.exe')
];

// Maximum number of redirects to follow
const MAX_REDIRECTS = 5;

// Function to make HTTPS GET requests with GitHub API headers
function httpsGet(url, headers = {}, redirectCount = 0) {
    return new Promise((resolve, reject) => {
        if (redirectCount > MAX_REDIRECTS) {
            return reject(new Error('Too many redirects'));
        }

        const options = {
            headers: {
                'User-Agent': 'Node.js Script',
                ...headers
            }
        };
        https.get(url, options, (res) => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                // Handle redirects
                resolve(httpsGet(res.headers.location, headers, redirectCount + 1));
                return;
            }
            if (res.statusCode !== 200) {
                reject(new Error(`Request Failed. Status Code: ${res.statusCode}`));
                res.resume(); // Consume response data to free up memory
                return;
            }
            let data = '';
            res.setEncoding('utf8');
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => resolve(data));
        }).on('error', (e) => reject(e));
    });
}

// Function to download a file from a URL, handling redirects and showing progress
function downloadFile(url, dest, headers = {}, redirectCount = 0) {
    return new Promise((resolve, reject) => {
        if (redirectCount > MAX_REDIRECTS) {
            return reject(new Error('Too many redirects'));
        }

        const options = {
            headers: {
                'User-Agent': 'Node.js Script',
                ...headers
            }
        };

        https.get(url, options, (res) => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                // Handle redirects
                console.log(`Redirecting to ${res.headers.location}`);
                downloadFile(res.headers.location, dest, headers, redirectCount + 1).then(resolve).catch(reject);
                return;
            }

            if (res.statusCode !== 200) {
                reject(new Error(`Failed to get '${url}' (${res.statusCode})`));
                res.resume();
                return;
            }

            const totalSize = parseInt(res.headers['content-length'], 10);
            let downloadedSize = 0;

            const file = fs.createWriteStream(dest);
            res.pipe(file);

            res.on('data', (chunk) => {
                downloadedSize += chunk.length;
                if (totalSize) {
                    const percent = ((downloadedSize / totalSize) * 100).toFixed(2);
                    process.stdout.write(`Downloading... ${percent}%\r`);
                } else {
                    process.stdout.write(`Downloading... ${downloadedSize} bytes\r`);
                }
            });

            file.on('finish', () => {
                file.close(() => {
                    process.stdout.write('\n');
                    resolve();
                });
            });

            file.on('error', (err) => {
                fs.unlink(dest, () => reject(err));
            });
        }).on('error', (err) => {
            reject(err);
        });
    });
}

// Function to execute a shell command synchronously
function execCommand(command, cwd = process.cwd()) {
    try {
        execSync(command, { stdio: 'inherit', cwd });
    } catch (error) {
        throw new Error(`Command failed: ${command}\n${error.message}`);
    }
}

// Function to check if a command exists
function commandExists(command) {
    try {
        execSync(`where ${command}`, { stdio: 'ignore' });
        return true;
    } catch {
        return false;
    }
}

// Function to find 7z.exe in common installation paths
function find7zExecutable() {
    // First, check if 7z is in PATH
    if (commandExists('7z')) {
        console.log('Found 7z.exe in PATH.');
        return '7z';
    }

    // Search in common installation directories
    for (const potentialPath of COMMON_7Z_PATHS) {
        if (fs.existsSync(potentialPath)) {
            console.log(`Found 7z.exe at: ${potentialPath}`);
            return `"${potentialPath}"`; // Quote the path in case it contains spaces
        }
    }

    // If not found, throw an error
    throw new Error('7z.exe not found. Please install 7-Zip and ensure 7z.exe is in your PATH or installed in a common directory.');
}

// Main Build Function
(async function buildAnimeJanai() {
    try {
        console.log('=== Build AnimeJaNai Script Started ===');

        // Locate 7z.exe
        const sevenZipPath = find7zExecutable();

        // Create temporary directory
        if (fs.existsSync(TEMP_DIR)) {
            fs.rmSync(TEMP_DIR, { recursive: true, force: true });
        }
        fs.mkdirSync(TEMP_DIR, { recursive: true });
        console.log(`Created temporary directory at ${TEMP_DIR}`);

        // Step 1: Fetch latest release info from GitHub
        console.log('Fetching latest release information from GitHub...');
        const releaseData = await httpsGet(GITHUB_API_URL);
        const releaseJson = JSON.parse(releaseData);
        const version = releaseJson.tag_name || 'latest';
        console.log(`Latest version: ${version}`);

        // Step 2: Find the 'full-package' .7z asset
        const assets = releaseJson.assets;
        const fullPackageAsset = assets.find(asset => asset.name.includes('full-package') && asset.name.endsWith('.7z'));

        if (!fullPackageAsset) {
            throw new Error("No 'full-package' .7z asset found in the latest release.");
        }

        const downloadUrl = fullPackageAsset.browser_download_url;
        const assetName = fullPackageAsset.name;
        const downloadedFilePath = path.join(TEMP_DIR, assetName);

        console.log(`Downloading asset: ${assetName}`);
        await downloadFile(downloadUrl, downloadedFilePath);
        console.log(`Downloaded to ${downloadedFilePath}`);

        // Step 3: Extract the .7z archive
        const extractDir = path.join(TEMP_DIR, 'extracted');
        fs.mkdirSync(extractDir, { recursive: true });
        console.log(`Extracting ${downloadedFilePath} to ${extractDir}...`);
        execCommand(`${sevenZipPath} x "${downloadedFilePath}" -o"${extractDir}" -y`, TEMP_DIR);
        console.log('Extraction complete.');

        // Step 4: Identify the root directory inside the extracted folder
        const extractedItems = fs.readdirSync(extractDir);
        let rootDir = extractDir;

        if (extractedItems.length === 1 && fs.lstatSync(path.join(extractDir, extractedItems[0])).isDirectory()) {
            rootDir = path.join(extractDir, extractedItems[0]);
            console.log(`Detected root directory: ${rootDir}`);
        } else {
            console.log('No single root directory detected. Proceeding with extracted contents.');
        }

        // Step 5: Delete specified files
        console.log('Deleting specified files...');
        FILES_TO_DELETE.forEach(file => {
            const filePath = path.join(rootDir, file);
            if (fs.existsSync(filePath)) {
                fs.unlinkSync(filePath);
                console.log(`Deleted file: ${filePath}`);
            } else {
                console.log(`File not found (skipped): ${filePath}`);
            }
        });

        // Step 6: Delete specified folders
        console.log('Deleting specified folders...');
        FOLDERS_TO_DELETE.forEach(folder => {
            const folderPath = path.join(rootDir, folder);
            if (fs.existsSync(folderPath)) {
                fs.rmSync(folderPath, { recursive: true, force: true });
                console.log(`Deleted folder: ${folderPath}`);
            } else {
                console.log(`Folder not found (skipped): ${folderPath}`);
            }
        });

        // Step 7: Modify portable_config/input.conf
        const portableConfigDir = path.join(rootDir, 'portable_config');
        const inputConfPath = path.join(portableConfigDir, 'input.conf');

        if (fs.existsSync(inputConfPath)) {
            fs.writeFileSync(inputConfPath, NEW_INPUT_CONF_CONTENT, 'utf8');
            console.log(`Modified input.conf at ${inputConfPath}`);
        } else {
            console.warn(`input.conf not found at ${inputConfPath}. Skipping modification.`);
        }

        // Step 8: Modify mpv.conf
        const mpvConfPath = path.join(portableConfigDir, 'mpv.conf'); // Corrected path

        if (fs.existsSync(mpvConfPath)) {
            let mpvConfContent = fs.readFileSync(mpvConfPath, 'utf8');

            // Replace vo={something} with vo=libmpv
            mpvConfContent = mpvConfContent.replace(/^vo=.*/m, 'vo=libmpv');

            // Remove specified lines
            LINES_TO_DELETE_IN_MPV_CONF.forEach(line => {
                const regex = new RegExp(`^${line}$`, 'm');
                mpvConfContent = mpvConfContent.replace(regex, '');
            });

            // Write the modified content back
            fs.writeFileSync(mpvConfPath, mpvConfContent, 'utf8');
            console.log(`Modified mpv.conf at ${mpvConfPath}`);
        } else {
            console.warn(`mpv.conf not found at ${mpvConfPath}. Skipping modification.`);
        }

        // Step 9: Repack the modified files into a new .7z archive
        const outputVersion = version.startsWith('v') ? version.slice(1) : version;
        const outputFilename = OUTPUT_FILENAME_TEMPLATE.replace('{version}', outputVersion);
        const outputFilePath = path.join(OUTPUT_DIR, outputFilename);

        // Ensure output directory exists
        fs.mkdirSync(OUTPUT_DIR, { recursive: true });

        console.log(`Packing modified files into ${outputFilePath} with maximum compression...`);

        // Change working directory to rootDir to ensure files are added directly
        execCommand(`${sevenZipPath} a -t7z "${outputFilePath}" * -mx=9`, rootDir);
        console.log(`Packaged archive created at ${outputFilePath}`);

        // Step 10: Cleanup temporary directory
        console.log(`Cleaning up temporary files at ${TEMP_DIR}...`);
        fs.rmSync(TEMP_DIR, { recursive: true, force: true });
        console.log('Cleanup complete.');

        console.log('=== Build AnimeJaNai Script Completed Successfully ===');
    } catch (error) {
        console.error('Error during build:', error.message);
        process.exit(1);
    }
})();
