require('dotenv').config({ path: require('path').join(__dirname, '.env') });

const axios  = require('axios');
const fs     = require('fs');
const path   = require('path');
const { execSync } = require('child_process');

// ── Config ────────────────────────────────────────────────────
const SERVER_URL       = process.env.SERVER_URL || 'https://print-agm.onrender.com';
const AGENT_KEY        = process.env.AGENT_KEY  || 'printhub-agent-secret';
const PRINTER_NAME     = process.env.PRINTER_NAME || '';
const POLL_INTERVAL_MS = 5000;

const headers = { 'x-agent-key': AGENT_KEY };
const tempDir = path.join(__dirname, 'temp');
if (!fs.existsSync(tempDir)) fs.mkdirSync(tempDir);

// ── Print a PDF using Windows built-in (no SumatraPDF needed) ─
function printPDF(filePath, printerName) {
    // Use Windows Shell to print — works on every Windows PC
    // with any PDF viewer (Edge, Adobe, etc.) installed
    const printer = printerName || PRINTER_NAME || '';
    const safeFile = filePath.replace(/'/g, "''");

    let cmd;
    if (printer) {
        // Print to specific printer
        cmd = `powershell -NoProfile -WindowStyle Hidden -Command "` +
              `$shell = New-Object -ComObject Shell.Application; ` +
              `$item = $shell.Namespace(0).ParseName('${safeFile}'); ` +
              `$item.InvokeVerbEx('printto', '${printer.replace(/'/g, "''")}')` +
              `"`;
    } else {
        // Print to default printer
        cmd = `powershell -NoProfile -WindowStyle Hidden -Command "` +
              `Start-Process -FilePath '${safeFile}' -Verb Print -Wait` +
              `"`;
    }

    execSync(cmd, { timeout: 30000 });
}

// ── Startup ───────────────────────────────────────────────────
console.log('');
console.log('  ==========================================');
console.log('    PrintHub Print Agent');
console.log('  ==========================================');
console.log(`  Server  : ${SERVER_URL}`);
console.log(`  Printer : ${PRINTER_NAME || '(Windows default)'}`);
console.log(`  Polling : every ${POLL_INTERVAL_MS / 1000} seconds`);
console.log('');
console.log('  Waiting for print jobs...');
console.log('');

// ── Heartbeat ─────────────────────────────────────────────────
async function sendHeartbeat() {
    try {
        const r = await axios.post(`${SERVER_URL}/api/agent/heartbeat`,
            {}, { headers, timeout: 8000 });
        console.log(`  [${now()}] Online — Location: ${r.data.locationName}`);
    } catch (_) {}
}

// ── Poll loop ─────────────────────────────────────────────────
async function pollAndPrint() {
    try {
        const { data: jobs } = await axios.get(
            `${SERVER_URL}/api/agent/pending-jobs`,
            { headers, timeout: 10000 }
        );
        if (!jobs.length) return;

        console.log(`\n  [${now()}] Found ${jobs.length} job(s)`);

        for (const job of jobs) {
            await processJob(job);
        }
    } catch (err) {
        if (err.code === 'ECONNREFUSED' || err.code === 'ENOTFOUND') {
            console.log(`  [${now()}] Cannot reach server — check internet`);
        }
        // Silent on other errors — keep polling
    }
}

async function processJob(job) {
    const jobId   = job._id;
    const tmpFile = path.join(tempDir, `job_${jobId}.pdf`);
    const fileUrl = job.fileUrl.replace(
        /http:\/\/(localhost|127\.0\.0\.1):\d+/, SERVER_URL
    );

    console.log(`  Printing: "${job.fileName}" (${job.pages} pages)`);

    try {
        // Mark as printing
        await axios.post(`${SERVER_URL}/api/agent/update-job`,
            { jobId, status: 'printing' }, { headers });

        // Download PDF
        process.stdout.write('  Downloading... ');
        const response = await axios.get(fileUrl, {
            responseType: 'arraybuffer',
            headers,
            timeout: 60000
        });
        fs.writeFileSync(tmpFile, response.data);
        console.log('done');

        // Print
        process.stdout.write('  Sending to printer... ');
        printPDF(tmpFile, PRINTER_NAME);
        console.log('done ✓');

        // Mark completed
        await axios.post(`${SERVER_URL}/api/agent/update-job`,
            { jobId, status: 'completed' }, { headers });

        if (fs.existsSync(tmpFile)) fs.unlinkSync(tmpFile);
        console.log(`  Job complete!\n`);

    } catch (err) {
        console.log(`  FAILED: ${err.message}`);
        try {
            await axios.post(`${SERVER_URL}/api/agent/update-job`,
                { jobId, status: 'failed' }, { headers });
        } catch (_) {}
        if (fs.existsSync(tmpFile)) fs.unlinkSync(tmpFile);
    }
}

function now() {
    return new Date().toLocaleTimeString();
}

// Start
sendHeartbeat();
setInterval(sendHeartbeat, 30000);
pollAndPrint();
setInterval(pollAndPrint, POLL_INTERVAL_MS);
