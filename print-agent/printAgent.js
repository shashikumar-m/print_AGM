const axios = require('axios');
const fs = require('fs');
const path = require('path');
const { print } = require('pdf-to-printer');

// ============ CONFIG ============
// This is your Render server URL
const SERVER_URL = process.env.SERVER_URL || 'https://print-agm.onrender.com';
const AGENT_KEY  = process.env.AGENT_KEY  || 'printhub-agent-secret';
const POLL_INTERVAL_MS = 5000; // check every 5 seconds

const headers = { 'x-agent-key': AGENT_KEY };
const tempDir = path.join(__dirname, 'temp');
if (!fs.existsSync(tempDir)) fs.mkdirSync(tempDir);

console.log(`🖨️  PrintHub Agent started`);
console.log(`📡 Server: ${SERVER_URL}`);
console.log(`⏱️  Polling every ${POLL_INTERVAL_MS / 1000}s for pending jobs...\n`);

// ============ MAIN POLL LOOP ============
async function pollAndPrint() {
    try {
        const { data: jobs } = await axios.get(`${SERVER_URL}/api/agent/pending-jobs`, { headers });

        if (jobs.length === 0) return; // nothing to do

        console.log(`📋 Found ${jobs.length} pending job(s)`);

        for (const job of jobs) {
            await processJob(job);
        }
    } catch (err) {
        if (err.code === 'ECONNREFUSED' || err.code === 'ENOTFOUND') {
            console.error('❌ Cannot reach server. Check SERVER_URL and internet connection.');
        } else {
            console.error('❌ Poll error:', err.message);
        }
    }
}

async function processJob(job) {
    const jobId = job._id;
    const tmpFile = path.join(tempDir, `job_${jobId}.pdf`);

    console.log(`\n🔄 Processing job: ${job.fileName} (${job.pages} pages, duplex: ${job.duplex})`);

    try {
        // Mark as printing
        await axios.post(`${SERVER_URL}/api/agent/update-job`,
            { jobId, status: 'printing' }, { headers });

        // Download the PDF
        console.log(`⬇️  Downloading: ${job.fileUrl}`);
        const response = await axios.get(job.fileUrl, {
            responseType: 'arraybuffer',
            timeout: 30000
        });
        fs.writeFileSync(tmpFile, response.data);
        console.log(`✅ Downloaded to: ${tmpFile}`);

        // Print it
        console.log(`🖨️  Sending to printer...`);
        await print(tmpFile, {
            duplex: job.duplex ? 'long-edge' : 'simplex'
        });
        console.log(`✅ Print job sent to printer!`);

        // Mark as completed
        await axios.post(`${SERVER_URL}/api/agent/update-job`,
            { jobId, status: 'completed' }, { headers });

        // Clean up temp file
        fs.unlinkSync(tmpFile);
        console.log(`🗑️  Temp file cleaned up`);

    } catch (err) {
        console.error(`❌ Job ${jobId} failed:`, err.message);
        // Mark as failed
        try {
            await axios.post(`${SERVER_URL}/api/agent/update-job`,
                { jobId, status: 'failed' }, { headers });
        } catch (_) {}
        // Clean up if file exists
        if (fs.existsSync(tmpFile)) fs.unlinkSync(tmpFile);
    }
}

// Start polling
pollAndPrint(); // run immediately on start
setInterval(pollAndPrint, POLL_INTERVAL_MS);
