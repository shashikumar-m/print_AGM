const axios  = require('axios');
const fs     = require('fs');
const path   = require('path');
const { execSync, spawn } = require('child_process');

// Load .env from print-agent folder
require('dotenv').config({ path: path.join(__dirname, '.env') });

// ── Config ────────────────────────────────────────────────────
const SERVER_URL       = process.env.SERVER_URL || 'https://print-agm.onrender.com';
const AGENT_KEY        = process.env.AGENT_KEY  || 'printhub-agent-secret';
const POLL_INTERVAL_MS = 5000;

// Set this to your printer name if you want to force a specific printer.
// Leave empty to use the Windows default printer.
// Example: const PRINTER_NAME = 'HP LaserJet 1020';
const PRINTER_NAME = process.env.PRINTER_NAME || '';

const headers = { 'x-agent-key': AGENT_KEY };
const tempDir = path.join(__dirname, 'temp');
if (!fs.existsSync(tempDir)) fs.mkdirSync(tempDir);

// ── Detect SumatraPDF ─────────────────────────────────────────
function findSumatra() {
    const candidates = [
        'C:\\Program Files\\SumatraPDF\\SumatraPDF.exe',
        'C:\\Program Files (x86)\\SumatraPDF\\SumatraPDF.exe',
        path.join(process.env.LOCALAPPDATA || '', 'SumatraPDF\\SumatraPDF.exe'),
        path.join(process.env.APPDATA || '', 'SumatraPDF\\SumatraPDF.exe'),
    ];
    for (const p of candidates) {
        if (fs.existsSync(p)) return p;
    }
    // Try PATH
    try { execSync('where SumatraPDF', { stdio: 'pipe' }); return 'SumatraPDF'; } catch (_) {}
    return null;
}

const SUMATRA = findSumatra();

// ── List printers via PowerShell ──────────────────────────────
function listPrinters() {
    try {
        const out = execSync(
            'powershell -NoProfile -Command "Get-Printer | Select-Object Name,Default | ConvertTo-Json"',
            { encoding: 'utf8', timeout: 10000 }
        );
        const printers = JSON.parse(out);
        const arr = Array.isArray(printers) ? printers : [printers];
        return arr;
    } catch (_) { return []; }
}

// ── Print a PDF file ──────────────────────────────────────────
function printFile(filePath, opts = {}) {
    return new Promise((resolve, reject) => {
        const printer = opts.printer || PRINTER_NAME || '';

        if (SUMATRA) {
            // Best option: SumatraPDF silent print
            const args = ['-print-to-default', '-silent'];
            if (printer) args.splice(0, 1, '-print-to', printer);
            if (opts.duplex) args.push('-print-settings', 'duplexlong');
            args.push(filePath);

            console.log(`   Using SumatraPDF: ${SUMATRA}`);
            const proc = spawn(SUMATRA, args, { stdio: 'pipe' });
            proc.on('close', code => {
                if (code === 0 || code === null) resolve();
                else reject(new Error(`SumatraPDF exited with code ${code}`));
            });
            proc.on('error', reject);

        } else {
            // Fallback: PowerShell PrintDocument via .NET
            // Works on all Windows without any extra install
            const printerArg = printer
                ? `$p.PrinterSettings.PrinterName = '${printer.replace(/'/g, "''")}'`
                : '';

            const ps = `
Add-Type -AssemblyName System.Drawing
$p = New-Object System.Drawing.Printing.PrintDocument
${printerArg}
$p.DocumentName = 'PrintHub Job'
$filePath = '${filePath.replace(/\\/g, '\\\\')}'
$p.add_PrintPage({
    param($sender, $e)
    $img = [System.Drawing.Image]::FromFile($filePath)
    $e.Graphics.DrawImage($img, $e.MarginBounds)
    $img.Dispose()
    $e.HasMorePages = $false
})
$p.Print()
$p.Dispose()
`.trim();

            // Better fallback: use Start-Process with the PDF's default handler (Adobe, Edge, etc.)
            // This is the most reliable cross-system approach
            const printCmd = printer
                ? `powershell -NoProfile -Command "Start-Process -FilePath '${filePath.replace(/'/g, "''")}' -Verb PrintTo -ArgumentList '${printer.replace(/'/g, "''")}' -Wait"`
                : `powershell -NoProfile -Command "Start-Process -FilePath '${filePath.replace(/'/g, "''")}' -Verb Print -Wait"`;

            console.log(`   Using PowerShell PrintTo (no SumatraPDF found)`);
            try {
                execSync(printCmd, { timeout: 30000, stdio: 'pipe' });
                resolve();
            } catch (e) {
                reject(new Error(`PowerShell print failed: ${e.message}`));
            }
        }
    });
}

// ── Startup info ──────────────────────────────────────────────
console.log('');
console.log('╔══════════════════════════════════════════╗');
console.log('║       PrintHub Print Agent               ║');
console.log('╚══════════════════════════════════════════╝');
console.log(`📡 Server  : ${SERVER_URL}`);
console.log(`🖨️  Printer : ${PRINTER_NAME || '(Windows default)'}`);
console.log(`🔧 Sumatra : ${SUMATRA || 'NOT FOUND — using PowerShell fallback'}`);
console.log(`⏱️  Polling : every ${POLL_INTERVAL_MS / 1000}s`);
console.log('');

if (!SUMATRA) {
    console.log('⚠️  TIP: Install SumatraPDF for best results:');
    console.log('   https://www.sumatrapdfreader.org/download-free-pdf-viewer');
    console.log('');
}

// List available printers
const printers = listPrinters();
if (printers.length) {
    console.log('🖨️  Available printers:');
    printers.forEach((p, i) => {
        console.log(`   ${i + 1}. ${p.Name}${p.Default ? ' ✅ (default)' : ''}`);
    });
    console.log('');
}

// ── Poll loop ─────────────────────────────────────────────────
async function pollAndPrint() {
    try {
        const { data: jobs } = await axios.get(
            `${SERVER_URL}/api/agent/pending-jobs`,
            { headers, timeout: 10000 }
        );
        if (!jobs.length) return;

        console.log(`\n📋 Found ${jobs.length} pending job(s) — ${new Date().toLocaleTimeString()}`);
        for (const job of jobs) {
            await processJob(job);
        }
    } catch (err) {
        if (err.code === 'ECONNREFUSED' || err.code === 'ENOTFOUND') {
            console.error('❌ Cannot reach server. Check internet connection.');
        } else {
            console.error('❌ Poll error:', err.message);
        }
    }
}

async function processJob(job) {
    const jobId   = job._id;
    const tmpFile = path.join(tempDir, `job_${jobId}.pdf`);
    const fileUrl = job.fileUrl.replace(/http:\/\/(localhost|127\.0\.0\.1):\d+/, SERVER_URL);

    console.log(`\n🔄 Job: "${job.fileName}"`);
    console.log(`   Pages: ${job.pages} | Color: ${job.colorMode || 'bw'} | Duplex: ${job.duplex} | ${job.pagesPerSheet || 1}up`);
    if (job.pageRangeFrom > 0) console.log(`   Range: p${job.pageRangeFrom}–${job.pageRangeTo}`);

    try {
        // Mark as printing so it won't be picked up again
        await axios.post(`${SERVER_URL}/api/agent/update-job`,
            { jobId, status: 'printing' }, { headers });

        // Download PDF from server (stored in MongoDB)
        console.log(`   ⬇️  Downloading...`);
        const response = await axios.get(fileUrl, {
            responseType: 'arraybuffer',
            headers,
            timeout: 60000
        });
        fs.writeFileSync(tmpFile, response.data);
        const sizeKB = Math.round(response.data.byteLength / 1024);
        console.log(`   ✅ Downloaded (${sizeKB} KB)`);

        // Send to printer
        console.log(`   🖨️  Sending to printer...`);
        await printFile(tmpFile, {
            printer: PRINTER_NAME,
            duplex:  job.duplex,
            color:   job.colorMode === 'color',
        });
        console.log(`   ✅ Print job sent successfully!`);

        // Mark completed
        await axios.post(`${SERVER_URL}/api/agent/update-job`,
            { jobId, status: 'completed' }, { headers });

        // Clean up
        if (fs.existsSync(tmpFile)) fs.unlinkSync(tmpFile);
        console.log(`   🗑️  Temp file removed`);

    } catch (err) {
        console.error(`\n   ❌ FAILED: ${err.message}`);
        if (err.response) {
            console.error(`   HTTP ${err.response.status}:`, JSON.stringify(err.response.data));
        }
        // Mark as failed so admin can see it
        try {
            await axios.post(`${SERVER_URL}/api/agent/update-job`,
                { jobId, status: 'failed' }, { headers });
        } catch (_) {}
        if (fs.existsSync(tmpFile)) fs.unlinkSync(tmpFile);
    }
}

// Start polling immediately, then every 5 seconds
pollAndPrint();
setInterval(pollAndPrint, POLL_INTERVAL_MS);
