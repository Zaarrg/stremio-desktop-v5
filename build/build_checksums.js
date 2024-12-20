/*
  generate_sums.js
  Usage:
    node generate_sums.js "C:\\Program Files\\OpenSSL-Win64\\bin" "5.0.0-beta.1" "5.0.0" 4.20.11

  This script:
    1) Validates four arguments:
       -- OPENSSL_BIN  (path to folder containing openssl.exe)
       -- GIT_TAG      (e.g. "5.0.0-beta.1")
       -- SHELL_VERSION (e.g. "5.0.0")
       -- SERVER_VERSION (e.g. "4.20.11")
    2) Locates and verifies "openssl.exe" in OPENSSL_BIN.
    3) Computes sha256 checksums of "Stremio <SHELL_VERSION>.exe" and "server.js" using
       "openssl dgst -sha256".
    4) Updates version-details.json to:
         shellVersion = SHELL_VERSION
         windows.url = https://github.com/Zaarrg/stremio-desktop-v5/releases/download/<GIT_TAG>/Stremio.<SHELL_VERSION>.exe
         windows.checksum = <exeSha256>
         server.js.url = https://dl.strem.io/server/<SERVER_VERSION>/desktop/server.js
         server.js.checksum = <serverSha256>
    5) Signs version-details.json with private_key.pem, base64-encodes the signature,
       inserts that signature into version.json.
    6) Cleans up the signature files (version-details.json.sig / .sig.b64).
    7) Exits 0 on success; 1 on any error.

  No external packages needed; we only use Node's built-in fs, path, child_process [[1]].
*/

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

// Parse CLI arguments
// e.g. node generate_sums.js "C:\\OpenSSL\\bin" "5.0.0-beta.1" "5.0.0" 4.20.11
const [,, OPENSSL_BIN, GIT_TAG, SHELL_VERSION, SERVER_VERSION] = process.argv;

(async function main() {
    // 1) Validate args
    if (!OPENSSL_BIN || !GIT_TAG || !SHELL_VERSION || !SERVER_VERSION) {
        console.error("Usage: node generate_sums.js <OpenSSLBinPath> <GitTag> <ShellVersion> <ServerVersion>");
        console.error('Example: node generate_sums.js "C:\\Program Files\\OpenSSL-Win64\\bin" "5.0.0-beta.1" "5.0.0" 4.20.11');
        process.exit(1);
    }

    // 2) Verify openssl.exe
    const opensslExe = path.join(OPENSSL_BIN, "openssl.exe");
    if (!fs.existsSync(opensslExe)) {
        console.error("ERROR: Cannot find openssl.exe in:", opensslExe);
        process.exit(1);
    }

    console.log("Using OpenSSL at:", OPENSSL_BIN);
    console.log("Git Tag:", GIT_TAG);
    console.log("Shell Version:", SHELL_VERSION);
    console.log("server.js Version:", SERVER_VERSION);
    console.log();

    // 3) Build paths
    //    Assume this script is in /build; go up one directory for the project root
    const scriptDir = path.dirname(__filename);
    const projectRoot = path.resolve(scriptDir, "..");

    // For Windows .exe, the local file name uses the Shell Version (5.0.0), not the Git tag
    const EXE_PATH = path.join(projectRoot, "utils", `Stremio ${SHELL_VERSION}.exe`);
    const SERVERJS_PATH = path.join(projectRoot, "utils", "windows", "server.js");
    const VERSION_DETAILS_PATH = path.join(projectRoot, "version", "version-details.json");
    const VERSION_JSON_PATH = path.join(projectRoot, "version", "version.json");
    const PRIVATE_KEY = path.join(projectRoot, "private_key.pem");

    // 4) Generate SHA-256 for the .exe and server.js
    checkFileExists(EXE_PATH, "Stremio .exe");
    const exeHash = computeSha256(opensslExe, EXE_PATH);

    checkFileExists(SERVERJS_PATH, "server.js");
    const serverHash = computeSha256(opensslExe, SERVERJS_PATH);

    console.log("EXE sha256      =", exeHash);
    console.log("server.js sha256 =", serverHash);
    console.log();

    // 5) Update version-details.json
    checkFileExists(VERSION_DETAILS_PATH, "version-details.json");
    let versionDetails;
    try {
        versionDetails = JSON.parse(fs.readFileSync(VERSION_DETAILS_PATH, "utf8"));
    } catch (err) {
        console.error("ERROR: Unable to parse version-details.json:", err.message);
        process.exit(1);
    }

    // Update:
    //   versionDetails.shellVersion = SHELL_VERSION
    //   versionDetails.files.windows.url => uses GIT_TAG
    //   versionDetails.files.windows.checksum => exeHash
    //   versionDetails.files["server.js"].url => uses SERVER_VERSION
    //   versionDetails.files["server.js"].checksum => serverHash
    versionDetails.shellVersion = SHELL_VERSION;
    if (!versionDetails.files) {
        console.error("ERROR: version-details.json missing property 'files'");
        process.exit(1);
    }
    if (!versionDetails.files.windows) versionDetails.files.windows = {};
    versionDetails.files.windows.url = `https://github.com/Zaarrg/stremio-desktop-v5/releases/download/${GIT_TAG}/Stremio.${SHELL_VERSION}.exe`;
    versionDetails.files.windows.checksum = exeHash;

    if (!versionDetails.files["server.js"]) versionDetails.files["server.js"] = {};
    versionDetails.files["server.js"].url = `https://dl.strem.io/server/${SERVER_VERSION}/desktop/server.js`;
    versionDetails.files["server.js"].checksum = serverHash;

    // Save updated version-details.json
    try {
        fs.writeFileSync(VERSION_DETAILS_PATH, JSON.stringify(versionDetails, null, 2), "utf8");
    } catch (e) {
        console.error("ERROR: Failed writing version-details.json:", e.message);
        process.exit(1);
    }

    // 6) Sign version-details.json & base64-encode
    checkFileExists(PRIVATE_KEY, "private_key.pem");
    process.chdir(path.join(projectRoot, "version"));

    const sigFile = path.join(process.cwd(), "version-details.json.sig");
    const sigB64  = path.join(process.cwd(), "version-details.json.sig.b64");
    if (fs.existsSync(sigFile)) fs.unlinkSync(sigFile);
    if (fs.existsSync(sigB64))  fs.unlinkSync(sigB64);

    console.log(`Signing version-details.json with ${PRIVATE_KEY}...`);
    try {
        execFileSync(opensslExe, ["dgst", "-sha256", "-sign", PRIVATE_KEY, "-out", "version-details.json.sig", "version-details.json"], { stdio: "inherit" });
    } catch (err) {
        console.error("ERROR: Signing failed:", err.message);
        process.exit(1);
    }

    try {
        execFileSync(opensslExe, ["base64", "-in", "version-details.json.sig", "-out", "version-details.json.sig.b64"], { stdio: "inherit" });
    } catch (err) {
        console.error("ERROR: Base64 encoding failed:", err.message);
        process.exit(1);
    }

    if (!fs.existsSync(sigB64)) {
        console.error("ERROR: Could not create signature file:", sigB64);
        process.exit(1);
    }
    process.chdir(projectRoot);

    // 7) Insert signature into version.json
    checkFileExists(VERSION_JSON_PATH, "version.json");
    console.log(`Updating signature in "${VERSION_JSON_PATH}"...`);
    let signatureB64;
    try {
        signatureB64 = fs.readFileSync(sigB64, "utf8").replace(/\r?\n/g, "");
    } catch (err) {
        console.error("ERROR: Unable to read version-details.json.sig.b64:", err.message);
        process.exit(1);
    }

    let versionJson;
    try {
        versionJson = JSON.parse(fs.readFileSync(VERSION_JSON_PATH, "utf8"));
    } catch (err) {
        console.error("ERROR: Unable to parse version.json:", err.message);
        process.exit(1);
    }

    versionJson.signature = signatureB64;
    try {
        fs.writeFileSync(VERSION_JSON_PATH, JSON.stringify(versionJson, null, 2), "utf8");
    } catch (err) {
        console.error("ERROR: Unable to write version.json:", err.message);
        process.exit(1);
    }

    // 8) Cleanup ephemeral files
    try {
        if (fs.existsSync(sigFile)) fs.unlinkSync(sigFile);
        if (fs.existsSync(sigB64)) fs.unlinkSync(sigB64);
    } catch (cleanupErr) {
        console.error("WARNING: Could not remove signature files:", cleanupErr.message);
    }

    console.log("\nSuccess! Checksums and signature have been updated, ephemeral signature files removed.");
    process.exit(0);

})().catch(err => {
    console.error("Unexpected error:", err);
    process.exit(1);
});

// Helper: checks that filePath exists, else exits
function checkFileExists(filePath, label) {
    if (!fs.existsSync(filePath)) {
        console.error(`ERROR: ${label} file not found at: ${filePath}`);
        process.exit(1);
    }
}

// Helper: runs "openssl dgst -sha256 <file>" and parses the output
function computeSha256(opensslExe, filePath) {
    try {
        const output = execFileSync(opensslExe, ["dgst", "-sha256", filePath], { encoding: "utf8" });
        // Typically "SHA256(file)= <hexhash>"
        const match = output.match(/=.\s*([0-9a-fA-F]+)/);
        if (!match) {
            console.error("ERROR: Unexpected openssl dgst output for", filePath, "-", output);
            process.exit(1);
        }
        return match[1].toLowerCase();
    } catch (err) {
        console.error(`ERROR: openssl dgst failed for ${filePath}:`, err.message);
        process.exit(1);
    }
}