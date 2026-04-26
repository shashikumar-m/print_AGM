const axios = require('axios');
const fs    = require('fs');
const path  = require('path');
const { print, getPrinters } = require('pdf-to-printer');

const SERVER_URL       = process.env.SERVER_URL || 'https://print-agm.onrender.com';
const AGENT_KEY        = process.env.AGENT_KEY  || 'printhub-agent-secret';
const POLL_INTERVAL_MS = 5000;

const headers = { 'x-agent-key': AGENT_KEY };
const tempDir = path.join(__dirname, 'temp');
if (!fs.existsSync(tempDir)) fs.mkdirSync(tempDir);

console.log('🖨️  PrintHub Agent started');
console.log(`📡 Server : ${SERVER_URL}`);
console.log(`⏱️  Polling every ${POLL_INTERVAL_MS / 1000}s\n`);

getPrinters().then(printers => {
    if (!printers.length) {
        console.warn('⚠️  No printers found!');
    } else {
        console.log('🖨️  Available printers:');
        printers.forEach((p, i) => console.log(`   ${i + 1}. ${p.name}${p.isDefault ? ' ✅ (default)' : ''}`));
    }
    console.log('');
}).catch(err => console.warn('⚠️  Could not list printers:', err.message));

function fixUrl(url) {
    return url.replace(/http:\/\/(localhost|127\.0\.0\.1):\d+/, SERVER_URL);
}

async function pollAndPrint() {
    try {
        const { data: jobs } = await axios.get(`${SERVER_URL}/api/agent/pending-jobs`, { headers, timeout: 10000 });
        if (!jobs.length) return;
        console.log(`📋 Found ${jobs.length} pending job(s)`);
        for (const job of jobs) await processJob(job);
    } catch (err) {
        if (err.code === 'ECONNREFUSED' || err.code === 'ENOTFOUND')
            console.error('❌ Cannot reach server:', SERVER_URL);
        else
            console.error('❌ Poll error:', err.message);
    }
}

async function processJob(job) {
    const jobId   = job._id;
    const tmpFile = path.join(tempDir, `job_${jobId}.pdf`);
    const fileUrl = fixUrl(job.fileUrl);

    console.log(`\n🔄 "${job.fileName}" | ${job.pages}p | ${job.colorMode || 'bw'} | duplex:${job.duplex} | ${job.pagesPerSheet || 1}up`);
    if (job.pageRangeFrom > 0) console.log(`   Pages: ${job.pageRangeFrom}-${job.pageRangeTo}`);

    try {
        await axios.post(`${SERVER_URL}/api/agent/update-job`, { jobId, status: 'printing' }, { headers });

        const response = await axios.get(fileUrl, { responseType: 'arraybuffer', headers, timeout: 30000 });
        fs.writeFileSync(tmpFile, response.data);
        console.log('   ✅ Downloaded');

        // Build pdf-to-printer options
        const opts = {};
        if (job.duplex)                opts.duplex        = 'long-edge';
        if (job.colorMode === 'bw')    opts.monochrome    = true;
        if (job.pagesPerSheet > 1)     opts.nup           = job.pagesPerSheet;
        if (job.pageRangeFrom > 0 && job.pageRangeTo >= job.pageRangeFrom)
            opts.pages = `${job.pageRangeFrom}-${job.pageRangeTo}`;

        console.log('   🖨️  Printing with options:', opts);
        await print(tmpFile, opts);
        console.log('   ✅ Sent to printer!');

        await axios.post(`${SERVER_URL}/api/agent/update-job`, { jobId, status: 'completed' }, { headers });
        fs.unlinkSync(tmpFile);

    } catch (err) {
        console.error(`\n   ❌ FAILED: ${err.message}`);
        if (err.response) console.error(`   HTTP ${err.response.status}:`, JSON.stringify(err.response.data));
        try { await axios.post(`${SERVER_URL}/api/agent/update-job`, { jobId, status: 'failed' }, { headers }); } catch (_) {}
        if (fs.existsSync(tmpFile)) fs.unlinkSync(tmpFile);
    }
}

pollAndPrint();
setInterval(pollAndPrint, POLL_INTERVAL_MS);
