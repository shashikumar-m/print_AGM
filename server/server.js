require('dotenv').config();

const express  = require('express');
const multer   = require('multer');
const path     = require('path');
const fs       = require('fs');
const jwt      = require('jsonwebtoken');
const bcrypt   = require('bcryptjs');
const mongoose = require('mongoose');

// ── pdf-parse (safe import) ──────────────────────────────────────────────────
let pdfParse = null;
try { pdfParse = require('pdf-parse'); } catch (_) {}

// ── Config ───────────────────────────────────────────────────────────────────
const PORT        = process.env.PORT        || 3000;
const JWT_SECRET  = process.env.JWT_SECRET  || 'change-me-in-production';
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/printer_system';
const SERVER_URL  = process.env.SERVER_URL  || `http://localhost:${PORT}`;
const AGENT_KEY   = process.env.AGENT_KEY   || 'printhub-agent-secret';

// ── Ensure uploads dir exists ────────────────────────────────────────────────
const UPLOADS_DIR = path.join(__dirname, 'uploads');
if (!fs.existsSync(UPLOADS_DIR)) fs.mkdirSync(UPLOADS_DIR, { recursive: true });

// ── Express setup ────────────────────────────────────────────────────────────
const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));
app.use('/uploads', express.static(UPLOADS_DIR));
const upload = multer({ dest: UPLOADS_DIR });

// ── MongoDB ──────────────────────────────────────────────────────────────────
mongoose.connect(MONGODB_URI)
    .then(() => console.log('✅ MongoDB connected'))
    .catch(err => console.error('❌ MongoDB error:', err.message));

// ── Schemas ──────────────────────────────────────────────────────────────────
const userSchema = new mongoose.Schema({
    email:     { type: String, unique: true, required: true },
    password:  { type: String, required: true },
    role:      { type: String, enum: ['admin', 'student'], default: 'student' },
    name:      String,
    section:   String,
    wallet:    { type: Number, default: 0 },
    createdAt: { type: Date, default: Date.now }
});

const sectionSchema = new mongoose.Schema({
    name:      { type: String, required: true, unique: true },
    createdAt: { type: Date, default: Date.now }
});

const settingsSchema = new mongoose.Schema({
    pricePerPage:        { type: Number, default: 1 },
    // Print permissions controlled by admin
    allowColor:          { type: Boolean, default: true },
    allowDuplex:         { type: Boolean, default: true },
    allowPageRange:      { type: Boolean, default: true },
    allowPagesPerSheet:  { type: Boolean, default: true },
    maxPagesPerJob:      { type: Number, default: 0 }   // 0 = unlimited
});

const printJobSchema = new mongoose.Schema({
    studentId:      String,
    studentName:    String,
    studentSection: String,
    fileName:       String,
    pages:          Number,
    cost:           Number,
    status:         { type: String, enum: ['pending','printing','completed','failed'], default: 'pending' },
    // Print options
    duplex:         { type: Boolean, default: false },
    colorMode:      { type: String, enum: ['bw', 'color'], default: 'bw' },
    pageRangeFrom:  { type: Number, default: 0 },  // 0 = all
    pageRangeTo:    { type: Number, default: 0 },  // 0 = all
    pagesPerSheet:  { type: Number, default: 1 },  // 1, 2, or 4
    fileUrl:        String,
    fileData:       Buffer,
    createdAt:      { type: Date, default: Date.now }
});

const User     = mongoose.model('User',     userSchema);
const Section  = mongoose.model('Section',  sectionSchema);
const Settings = mongoose.model('Settings', settingsSchema);
const PrintJob = mongoose.model('PrintJob', printJobSchema);

// ── Seed ─────────────────────────────────────────────────────────────────────
async function initDB() {
    try {
        if (!await User.findOne({ email: 'admin@example.com' }))
            await User.create({ email: 'admin@example.com', password: bcrypt.hashSync('admin123', 10), role: 'admin', name: 'Admin' });
        if (!await User.findOne({ email: 'student@example.com' }))
            await User.create({ email: 'student@example.com', password: bcrypt.hashSync('student123', 10), role: 'student', name: 'John Doe', wallet: 500, section: 'CSE' });
        if (!await Settings.findOne())
            await Settings.create({});
        if (!await Section.findOne({ name: 'CSE' }))
            await Section.create({ name: 'CSE' });
        if (!await Section.findOne({ name: 'ECE' }))
            await Section.create({ name: 'ECE' });
    } catch (err) {
        console.log('initDB:', err.message);
    }
}
initDB();

// ── Middleware ────────────────────────────────────────────────────────────────
function verifyToken(req, res, next) {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ error: 'No token' });
    try { req.user = jwt.verify(token, JWT_SECRET); next(); }
    catch { res.status(403).json({ error: 'Invalid token' }); }
}

function verifyAgent(req, res, next) {
    if (req.headers['x-agent-key'] !== AGENT_KEY)
        return res.status(403).json({ error: 'Unauthorized' });
    next();
}

// ── Count PDF pages ───────────────────────────────────────────────────────────
async function countPages(filePath) {
    try {
        if (pdfParse) {
            const data = await pdfParse(fs.readFileSync(filePath));
            if (data && data.numpages) return data.numpages;
        }
    } catch (_) {}
    try {
        const m = fs.readFileSync(filePath, 'binary').match(/\/Count\s+(\d+)/);
        if (m) return parseInt(m[1]);
        return Math.max(1, Math.ceil(fs.statSync(filePath).size / 5000));
    } catch (_) { return 1; }
}

// ════════════════════════════════════════════════════════════════════════════
//  AUTH
// ════════════════════════════════════════════════════════════════════════════
app.post('/api/auth/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        const user = await User.findOne({ email });
        if (!user || !bcrypt.compareSync(password, user.password))
            return res.status(401).json({ error: 'Invalid credentials' });
        const token = jwt.sign(
            { id: user._id, email: user.email, role: user.role, name: user.name },
            JWT_SECRET
        );
        res.json({ token, user: { id: user._id, email: user.email, role: user.role, name: user.name, wallet: user.wallet, section: user.section } });
    } catch { res.status(500).json({ error: 'Login error' }); }
});

app.post('/api/auth/register', async (req, res) => {
    try {
        const { email, password, name, section } = req.body;
        if (await User.findOne({ email }))
            return res.status(400).json({ error: 'Email already exists' });
        await new User({ email, password: bcrypt.hashSync(password, 10), role: 'student', name, section, wallet: 0 }).save();
        res.json({ message: 'Registered successfully' });
    } catch { res.status(500).json({ error: 'Registration error' }); }
});

// ════════════════════════════════════════════════════════════════════════════
//  SECTIONS
// ════════════════════════════════════════════════════════════════════════════
app.get('/api/sections', async (req, res) => {
    try { res.json(await Section.find().sort({ name: 1 })); }
    catch { res.status(500).json({ error: 'Error fetching sections' }); }
});

app.post('/api/admin/sections', verifyToken, async (req, res) => {
    try {
        if (req.user.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
        const { name } = req.body;
        if (!name || !name.trim()) return res.status(400).json({ error: 'Section name required' });
        if (await Section.findOne({ name: name.trim().toUpperCase() }))
            return res.status(400).json({ error: 'Section already exists' });
        const section = await Section.create({ name: name.trim().toUpperCase() });
        res.json(section);
    } catch { res.status(500).json({ error: 'Error creating section' }); }
});

app.delete('/api/admin/sections/:id', verifyToken, async (req, res) => {
    try {
        if (req.user.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
        await Section.findByIdAndDelete(req.params.id);
        res.json({ message: 'Section deleted' });
    } catch { res.status(500).json({ error: 'Error deleting section' }); }
});

// ════════════════════════════════════════════════════════════════════════════
//  STUDENT
// ════════════════════════════════════════════════════════════════════════════
app.get('/api/student/wallet', verifyToken, async (req, res) => {
    try {
        if (req.user.role !== 'student') return res.status(403).json({ error: 'Unauthorized' });
        const student = await User.findById(req.user.id);
        if (!student) return res.status(404).json({ error: 'Student not found' });
        res.json({ wallet: student.wallet });
    } catch { res.status(500).json({ error: 'Error fetching wallet' }); }
});

app.post('/api/upload', verifyToken, upload.single('pdf'), async (req, res) => {
    try {
        if (req.user.role !== 'student')
            return res.status(403).json({ error: 'Only students can upload' });
        if (!req.file)
            return res.status(400).json({ error: 'No file uploaded' });

        const filePath = req.file.path;
        const totalPages = await countPages(filePath);

        // Parse print options
        const colorMode     = req.body.colorMode     || 'bw';
        const duplex        = req.body.duplex        === 'true';
        const pagesPerSheet = parseInt(req.body.pagesPerSheet) || 1;
        const pageFrom      = parseInt(req.body.pageFrom) || 0;
        const pageTo        = parseInt(req.body.pageTo)   || 0;

        // Calculate effective pages to print
        let effectivePages = totalPages;
        if (pageFrom > 0 && pageTo >= pageFrom) {
            effectivePages = pageTo - pageFrom + 1;
        }
        // Pages per sheet reduces paper used
        const paperSheets = Math.ceil(effectivePages / pagesPerSheet);

        const settings     = await Settings.findOne();
        const pricePerPage = settings?.pricePerPage || 1;

        // Validate permissions
        if (!settings?.allowColor && colorMode === 'color')
            return res.status(403).json({ error: 'Color printing is not allowed' });
        if (!settings?.allowDuplex && duplex)
            return res.status(403).json({ error: 'Duplex printing is not allowed' });
        if (!settings?.allowPageRange && (pageFrom > 0 || pageTo > 0))
            return res.status(403).json({ error: 'Custom page range is not allowed' });
        if (!settings?.allowPagesPerSheet && pagesPerSheet > 1)
            return res.status(403).json({ error: 'Multiple pages per sheet is not allowed' });
        if (settings?.maxPagesPerJob > 0 && effectivePages > settings.maxPagesPerJob)
            return res.status(403).json({ error: `Max ${settings.maxPagesPerJob} pages per job allowed` });

        const cost = paperSheets * pricePerPage;

        const student = await User.findById(req.user.id);
        if (!student) return res.status(404).json({ error: 'Student not found' });
        if (student.wallet < cost) {
            fs.unlinkSync(filePath);
            return res.status(402).json({ error: `Insufficient balance. Need ₹${cost}, have ₹${student.wallet}` });
        }

        student.wallet -= cost;
        await student.save();

        const fileData = fs.readFileSync(filePath);

        const printJob = await new PrintJob({
            studentId:      req.user.id,
            studentName:    req.user.name,
            studentSection: student.section || '',
            fileName:       req.file.originalname,
            pages:          effectivePages,
            cost,
            status:         'pending',
            duplex,
            colorMode,
            pageRangeFrom:  pageFrom,
            pageRangeTo:    pageTo,
            pagesPerSheet,
            fileUrl:        'pending',
            fileData
        }).save();

        printJob.fileUrl = `${SERVER_URL}/api/agent/download-job/${printJob._id}`;
        await printJob.save();

        fs.unlinkSync(filePath);

        res.json({
            message:         'PDF submitted for printing',
            pages:           effectivePages,
            totalPages,
            cost,
            remainingWallet: student.wallet,
            jobId:           printJob._id
        });
    } catch (err) {
        console.error('Upload error:', err);
        res.status(500).json({ error: 'Error processing PDF' });
    }
});

// ════════════════════════════════════════════════════════════════════════════
//  ADMIN
// ════════════════════════════════════════════════════════════════════════════
app.get('/api/admin/students', verifyToken, async (req, res) => {
    try {
        if (req.user.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
        res.json(await User.find({ role: 'student' }).select('-password'));
    } catch { res.status(500).json({ error: 'Error fetching students' }); }
});

app.post('/api/admin/add-wallet', verifyToken, async (req, res) => {
    try {
        if (req.user.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
        const { studentId, amount } = req.body;
        const student = await User.findById(studentId);
        if (!student) return res.status(404).json({ error: 'Student not found' });
        student.wallet += parseInt(amount);
        await student.save();
        res.json({ message: 'Wallet updated', wallet: student.wallet });
    } catch { res.status(500).json({ error: 'Error updating wallet' }); }
});

app.get('/api/admin/print-jobs', verifyToken, async (req, res) => {
    try {
        if (req.user.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
        res.json(await PrintJob.find().select('-fileData').sort({ createdAt: -1 }));
    } catch { res.status(500).json({ error: 'Error fetching print jobs' }); }
});

// ════════════════════════════════════════════════════════════════════════════
//  SETTINGS
// ════════════════════════════════════════════════════════════════════════════
app.get('/api/settings', async (req, res) => {
    try {
        let s = await Settings.findOne();
        if (!s) s = await Settings.create({});
        res.json(s);
    } catch { res.json({ pricePerPage: 1 }); }
});

app.post('/api/admin/settings', verifyToken, async (req, res) => {
    try {
        if (req.user.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
        const { pricePerPage, allowColor, allowDuplex, allowPageRange, allowPagesPerSheet, maxPagesPerJob } = req.body;
        if (pricePerPage !== undefined && pricePerPage <= 0)
            return res.status(400).json({ error: 'Invalid price' });
        let s = await Settings.findOne() || new Settings();
        if (pricePerPage       !== undefined) s.pricePerPage       = pricePerPage;
        if (allowColor         !== undefined) s.allowColor         = allowColor;
        if (allowDuplex        !== undefined) s.allowDuplex        = allowDuplex;
        if (allowPageRange     !== undefined) s.allowPageRange     = allowPageRange;
        if (allowPagesPerSheet !== undefined) s.allowPagesPerSheet = allowPagesPerSheet;
        if (maxPagesPerJob     !== undefined) s.maxPagesPerJob     = maxPagesPerJob;
        await s.save();
        res.json({ message: 'Settings updated', settings: s });
    } catch { res.status(500).json({ error: 'Error updating settings' }); }
});

// ════════════════════════════════════════════════════════════════════════════
//  PRINT AGENT
// ════════════════════════════════════════════════════════════════════════════
app.get('/api/agent/pending-jobs', verifyAgent, async (req, res) => {
    try {
        res.json(await PrintJob.find({ status: 'pending' }).select('-fileData').sort({ createdAt: 1 }));
    } catch { res.status(500).json({ error: 'Error fetching jobs' }); }
});

app.get('/api/agent/download-job/:jobId', verifyAgent, async (req, res) => {
    try {
        const job = await PrintJob.findById(req.params.jobId).select('fileData fileName');
        if (!job || !job.fileData) return res.status(404).json({ error: 'File not found' });
        res.set('Content-Type', 'application/pdf');
        res.set('Content-Disposition', `attachment; filename="${job.fileName}"`);
        res.send(job.fileData);
    } catch { res.status(500).json({ error: 'Error downloading file' }); }
});

app.post('/api/agent/update-job', verifyAgent, async (req, res) => {
    try {
        const { jobId, status } = req.body;
        await PrintJob.findByIdAndUpdate(jobId, { status });
        res.json({ message: 'Updated', jobId, status });
    } catch { res.status(500).json({ error: 'Error updating job' }); }
});

// ════════════════════════════════════════════════════════════════════════════
//  STATIC
// ════════════════════════════════════════════════════════════════════════════
app.get('/', (req, res) => res.sendFile(path.join(__dirname, 'public', 'index.html')));
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
