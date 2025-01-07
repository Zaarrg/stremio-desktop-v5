#!/usr/bin/env node

/**
 * build_anime4k.js
 *
 * This script performs the following: (Needed for deploy_windows to include Anime4k in installer)
 * 1. Determines the latest Anime4K version from bloc97/Anime4K releases.
 * 2. Downloads the corresponding GLSL_Windows_High-end.zip from Tama47/Anime4K.
 * 3. Auto-detects 7z.exe on the system.
 * 4. Saves the downloaded zip as anime4k-High-end.zip in utils/mpv.
 * 5. Extracts the zip into the anime4k folder.
 * 6. Cleans up temporary files.
 *
 * Usage:
 *   node build_anime4k.js
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const { execSync } = require('child_process');
const os = require('os');

// Configuration
const BLOC97_API_URL = 'https://api.github.com/repos/bloc97/Anime4K/releases/latest';
const TEMP_DIR = path.join(os.tmpdir(), 'anime4k_build_temp');
const OUTPUT_DIR = path.resolve(__dirname, '..', 'utils', 'mpv');
const OUTPUT_ZIP_NAME = 'anime4k-High-end.zip';
const EXTRACTION_DIR = path.join(OUTPUT_DIR, 'anime4k', 'portable_config');

// Common 7z.exe installation paths on Windows
const COMMON_7Z_PATHS = [
    path.join(process.env.PROGRAMFILES || 'C:\\Program Files', '7-Zip', '7z.exe'),
    path.join(process.env['PROGRAMFILES(X86)'] || 'C:\\Program Files (x86)', '7-Zip', '7z.exe'),
    path.join(process.env.LOCALAPPDATA || path.join(os.homedir(), 'AppData', 'Local'), '7-Zip', '7z.exe')
];

// Maximum number of redirects to follow
const MAX_REDIRECTS = 5;

// Helper Functions

function httpsGet(url, headers = {}, redirectCount = 0) {
    return new Promise((resolve, reject) => {
        if (redirectCount > MAX_REDIRECTS) return reject(new Error('Too many redirects'));

        const options = {
            headers: {
                'User-Agent': 'Node.js Script',
                ...headers
            }
        };
        https.get(url, options, (res) => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                return resolve(httpsGet(res.headers.location, headers, redirectCount + 1));
            }
            if (res.statusCode !== 200) {
                res.resume();
                return reject(new Error(`Request Failed. Status Code: ${res.statusCode}`));
            }
            let data = '';
            res.setEncoding('utf8');
            res.on('data', chunk => data += chunk);
            res.on('end', () => resolve(data));
        }).on('error', e => reject(e));
    });
}

function downloadFile(url, dest, headers = {}, redirectCount = 0) {
    return new Promise((resolve, reject) => {
        if (redirectCount > MAX_REDIRECTS) return reject(new Error('Too many redirects'));

        const options = {
            headers: {
                'User-Agent': 'Node.js Script',
                ...headers
            }
        };

        https.get(url, options, (res) => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                console.log(`Redirecting to ${res.headers.location}`);
                return resolve(downloadFile(res.headers.location, dest, headers, redirectCount + 1));
            }
            if (res.statusCode !== 200) {
                res.resume();
                return reject(new Error(`Failed to get '${url}' (${res.statusCode})`));
            }

            const totalSize = parseInt(res.headers['content-length'], 10);
            let downloadedSize = 0;
            const file = fs.createWriteStream(dest);
            res.pipe(file);

            res.on('data', chunk => {
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

            file.on('error', err => {
                fs.unlink(dest, () => reject(err));
            });
        }).on('error', err => reject(err));
    });
}

function execCommand(command, cwd = process.cwd()) {
    try {
        execSync(command, { stdio: 'inherit', cwd });
    } catch (error) {
        throw new Error(`Command failed: ${command}\n${error.message}`);
    }
}

function commandExists(command) {
    try {
        execSync(`where ${command}`, { stdio: 'ignore' });
        return true;
    } catch {
        return false;
    }
}

function find7zExecutable() {
    if (commandExists('7z')) {
        console.log('Found 7z.exe in PATH.');
        return '7z';
    }
    for (const potentialPath of COMMON_7Z_PATHS) {
        if (fs.existsSync(potentialPath)) {
            console.log(`Found 7z.exe at: ${potentialPath}`);
            return `"${potentialPath}"`;
        }
    }
    throw new Error('7z.exe not found. Please install 7-Zip.');
}

// Main Build Function
(async function buildAnime4K() {
    try {
        console.log('=== Build Anime4K Script Started ===');

        const sevenZipPath = find7zExecutable();

        if (fs.existsSync(TEMP_DIR)) fs.rmSync(TEMP_DIR, { recursive: true, force: true });
        fs.mkdirSync(TEMP_DIR, { recursive: true });
        console.log(`Created temporary directory at ${TEMP_DIR}`);

        console.log('Fetching latest Anime4K version information...');
        const releaseData = await httpsGet(BLOC97_API_URL);
        const releaseJson = JSON.parse(releaseData);
        const version = releaseJson.tag_name;
        console.log(`Latest version: ${version}`);

        const downloadUrl = `https://github.com/Tama47/Anime4K/releases/download/${version}/GLSL_Windows_High-end.zip`;
        const downloadedFilePath = path.join(TEMP_DIR, 'GLSL_Windows_High-end.zip');

        console.log(`Downloading GLSL_Windows_High-end.zip for version ${version}...`);
        await downloadFile(downloadUrl, downloadedFilePath);
        console.log(`Downloaded to ${downloadedFilePath}`);

        // Ensure output directory exists
        fs.mkdirSync(OUTPUT_DIR, { recursive: true });

        const outputZipPath = path.join(OUTPUT_DIR, OUTPUT_ZIP_NAME);
        fs.copyFileSync(downloadedFilePath, outputZipPath);
        console.log(`Saved zip as ${outputZipPath}`);

        // Extract the zip to the anime4k folder
        fs.mkdirSync(EXTRACTION_DIR, { recursive: true });
        console.log(`Extracting ${outputZipPath} to ${EXTRACTION_DIR}...`);
        execCommand(`${sevenZipPath} x "${outputZipPath}" -o"${EXTRACTION_DIR}" -y`);
        console.log('Extraction complete.');

        // Path to the mpv.conf file inside the extraction directory
        const mpvConfPath = path.join(EXTRACTION_DIR, 'mpv.conf');

        // Check if mpv.conf exists before attempting to modify it
        if (fs.existsSync(mpvConfPath)) {
            console.log(`Modifying ${mpvConfPath} to comment out glsl-shaders lines...`);
            // Read the existing content of mpv.conf
            let confData = fs.readFileSync(mpvConfPath, 'utf8');
            // Split the file into lines
            const lines = confData.split(/\r?\n/);
            // Map over lines to comment out ones that start with 'glsl-shaders='
            const modifiedLines = lines.map(line => {
                // Trim whitespace at beginning of line for accurate check
                const trimmedLine = line.trim();
                if (trimmedLine.startsWith('glsl-shaders=')) {
                    // If not already commented out, add a comment marker
                    if (!trimmedLine.startsWith('#')) {
                        return `# ${line}`;
                    }
                }
                return line;
            });
            // Join the modified lines back together
            confData = modifiedLines.join(os.EOL);
            // Write the changes back to mpv.conf
            fs.writeFileSync(mpvConfPath, confData, 'utf8');
            console.log('Modification complete.');
        } else {
            console.log(`Warning: ${mpvConfPath} not found. Skipping modification.`);
        }

        // Cleanup
        console.log(`Cleaning up temporary files at ${TEMP_DIR}...`);
        fs.rmSync(TEMP_DIR, { recursive: true, force: true });
        console.log('Cleanup complete.');

        console.log('=== Build Anime4K Script Completed Successfully ===');
        process.exit(1);
    } catch (error) {
        console.error('Error during build:', error.message);
        process.exit(1);
    }
})();
