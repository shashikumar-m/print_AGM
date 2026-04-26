/**
 * Marks all pending jobs whose files no longer exist on Render as 'failed'.
 * Run once: node mark-failed.js
 */
require('dotenv').config({ path: '../server/.env' });
const mongoose = require('mongoose');

const PrintJob = mongoose.model('PrintJob', new mongoose.Schema({
    status: String,
    fileUrl: String
}, { strict: false }));

mongoose.connect(process.env.MONGODB_URI).then(async () => {
    console.log('✅ Connected');

    const result = await PrintJob.updateMany(
        { status: 'pending' },
        { status: 'failed' }
    );

    console.log(`Marked ${result.modifiedCount} pending job(s) as failed.`);
    console.log('These were old jobs whose files no longer exist on Render.');
    console.log('New uploads will work correctly going forward.');

    await mongoose.disconnect();
}).catch(err => {
    console.error('Error:', err.message);
    process.exit(1);
});
