/**
 * Run this ONCE to fix jobs that have a localhost fileUrl stored in MongoDB.
 * Usage: node fix-jobs.js
 */
require('dotenv').config({ path: '../server/.env' });
const mongoose = require('mongoose');

const MONGODB_URI = process.env.MONGODB_URI;
const SERVER_URL  = process.env.SERVER_URL || 'https://print-agm.onrender.com';

if (!MONGODB_URI) {
    console.error('❌ MONGODB_URI not found. Make sure server/.env exists.');
    process.exit(1);
}

const printJobSchema = new mongoose.Schema({
    status:  String,
    fileUrl: String,
}, { strict: false });

const PrintJob = mongoose.model('PrintJob', printJobSchema);

async function fix() {
    await mongoose.connect(MONGODB_URI);
    console.log('✅ Connected to MongoDB');

    // Find all jobs with localhost in fileUrl
    const badJobs = await PrintJob.find({
        fileUrl: { $regex: /localhost|127\.0\.0\.1/ }
    });

    console.log(`Found ${badJobs.length} job(s) with localhost URL`);

    for (const job of badJobs) {
        const fixedUrl = job.fileUrl.replace(/http:\/\/(localhost|127\.0\.0\.1):\d+/, SERVER_URL);
        await PrintJob.findByIdAndUpdate(job._id, {
            fileUrl: fixedUrl,
            status: 'pending'   // reset to pending so agent retries
        });
        console.log(`  Fixed: ${job.fileUrl}`);
        console.log(`     → : ${fixedUrl}`);
    }

    console.log('\n✅ Done. Restart the print agent to process these jobs.');
    await mongoose.disconnect();
}

fix().catch(err => {
    console.error('Error:', err.message);
    process.exit(1);
});
