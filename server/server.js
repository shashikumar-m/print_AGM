require('dotenv').config();

const express  = require('express');
const multer   = require('multer');
const axios    = require('axios');
const path     = require('path');
const fs       = require('fs');
const jwt      = require('jsonwebtoken');
const bcrypt   = require('bcryptjs');
const mongoose = require('mongoose');

// ── pdf-parse (safe import) ──────────────────────────────────────────────────
let pdfParse = null;
try { pdfParse = require('pdf-parse'); } catch (_) {}

// ── Config ───────────────────────────────────────────────────────────────────
const PORT       = process.env.PORT       || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'change-me-in-production';
const MONGODB_URI= process.env.MONGODB_URI|| 'mongodb://localhost:27017/printer_system';
const SERVER_URL = process.env.SERVER_URL || `http://localhost:${PORT}`;
const AGENT_KEY  = process.env.AGENT_KEY  || 'printhub-agent-secret';

// ── Ensure uploads dir exists (Render ephemeral FS) ─────────────────────────
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
    wallet:    { type: Number, default: 0 },
    createdAt: { type: Date, default: Date.now }
});

const settingsSchema = new mongoose.Schema({
    pricePerPage: { type: Number, default: 1 }
});

const printJobSchema = new mongoose.Schema({
    studentId:   String,
    studentName: String,
    fileName:    String,
    pages:       Number,
    cost:        Number,
    status:      { type: String, enum: ['pending','printing','completed','failed'], default: 'pending' },
    duplex:      Boolean,
    fileUrl:     String,
    createdAt:   { type: Date, default: Date.now }
});

const User     = mongoose.model('User',     userSchema);
const Settings = mongoose.model('Settings', settingsSchema);
const PrintJob = mongoose.model('PrintJob', printJobSchema);

// ── Seed default data ────────────────────────────────────────────────────────
async function initDB() {
    try {
        if (!await User.findOne({ email: 'admin@example.com' })) {
            await User.create({ email: 'admin@example.com', password: bcrypt.hashSync('admin123', 10), role: 'admin', name: 'Admin' });
        }
        if (!await User.findOne({ email: 'student@example.com' })) {
            await User.create({ email: 'student@example.com', password: bcrypt.hashSync('student123', 10), role: 'student', name: 'John Doe', wallet: 500 });
        }
        if (!await Settings.findOne()) {
            await Settings.create({ pricePerPage: 1 });
        }
    } catch (err) {
        console.log('initDB:', err.message);
    }
}
initDB();

// ── Auth middleware ───────────────────────────────────────────────────────────
function verifyToken(req, res, next) {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ error: 'No token' });
    try {
        req.user = jwt.verify(token, JWT_SECRET);
        next();
    } catch {
        res.status(403).json({ error: 'Invalid token' });
    }
}

// ── Count PDF pages ───────────────────────────────────────────────────────────
async function countPages(filePath) {
    try {
        if (pdfParse) {
            const buf  = fs.readFileSync(filePath);
            const data = await pdfParse(buf);
            if (data && data.numpages) return data.numpages;
        }
    } catch (_) {}

    // Fallback: scan raw bytes for /Count N
    try {
        const text = fs.readFileSync(filePath, 'binary');
        const m = text.match(/\/Count\s+(\d+)/);
        if (m) return parseInt(m[1]);
        return Math.max(1, Math.ceil(fs.statSync(filePath).size / 5000));
    } catch (_) {
        return 1;
    }
}

// ════════════════════════════════════════════════════════════════════════════
//  AUTH ROUTES
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
        res.json({ token, user: { id: user._id, email: user.email, role: user.role, name: user.name, wallet: user.wallet } });
    } catch (err) {
        res.status(500).json({ error: 'Login error' });
    }
});

app.post('/api/auth/register', async (req, res) => {
    try {
        const { email, password, name } = req.body;
        if (await User.findOne({ email }))
            return res.status(400).json({ error: 'Email already exists' });

        await new User({ email, password: bcrypt.hashSync(password, 10), role: 'student', name, wallet: 0 }).save();
        res.json({ message: 'Registered successfully' });
    } catch (err) {
        res.status(500).json({ error: 'Registration error' });
    }
});

// ════════════════════════════════════════════════════════════════════════════
//  STUDENT ROUTES
// ════════════════════════════════════════════════════════════════════════════
app.get('/api/student/wallet', verifyToken, async (req, res) => {
    try {
        if (req.user.role !== 'student') return res.status(403).json({ error: 'Unauthorized' });
        const student = await User.findById(req.user.id);
        if (!student) return res.status(404).json({ error: 'Student not found' });
        res.json({ wallet: student.wallet });
    } catch (err) {
        res.status(500).json({ error: 'Error fetching wallet' });
    }
});

app.post('/api/upload', verifyToken, upload.single('pdf'), async (req, res) => {
    try {
        if (req.user.role !== 'student')
            return res.status(403).json({ error: 'Only students can upload' });
        if (!req.file)
            return res.status(400).json({ error: 'No file uploaded' });

        const filePath = req.file.path;
        const pages    = await countPages(filePath);

        const settings    = await Settings.findOne();
        const pricePerPage= settings?.pricePerPage || 1;
        const cost        = pages * pricePerPage;

        const student = await User.findById(req.user.id);
        if (!student) return res.status(404).json({ error: 'Student not found' });

        if (student.wallet < cost) {
            fs.unlinkSync(filePath);
            return res.status(402).json({ error: `Insufficient balance. Need ₹${cost}, have ₹${student.wallet}` });
        }

        student.wallet -= cost;
        await student.save();

        // Build public URL so the print agent can download the file
        const fileUrl = `${SERVER_URL}/uploads/${req.file.filename}`;

        const printJob = await new PrintJob({
            studentId:   req.user.id,
            studentName: req.user.name,
            fileName:    req.file.originalname,
            pages, cost,
            status:  'pending',
            duplex:  req.body.duplex === 'true',
            fileUrl
        }).save();

        res.json({
            message:         'PDF submitted for printing',
            pages,
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
//  ADMIN ROUTES
// ════════════════════════════════════════════════════════════════════════════
app.get('/api/admin/students', verifyToken, async (req, res) => {
    try {
        if (req.user.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
        res.json(await User.find({ role: 'student' }).select('-password'));
    } catch (err) {
        res.status(500).json({ error: 'Error fetching students' });
    }
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
    } catch (err) {
        res.status(500).json({ error: 'Error updating wallet' });
    }
});

app.get('/api/admin/print-jobs', verifyToken, async (req, res) => {
    try {
        if (req.user.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
        res.json(await PrintJob.find().sort({ createdAt: -1 }));
    } catch (err) {
        res.status(500).json({ error: 'Error fetching print jobs' });
    }
});

// ════════════════════════════════════════════════════════════════════════════
//  SETTINGS ROUTES
// ════════════════════════════════════════════════════════════════════════════
app.get('/api/settings', async (req, res) => {
    try {
        let s = await Settings.findOne();
        if (!s) s = await Settings.create({ pricePerPage: 1 });
        res.json(s);
    } catch (err) {
        res.json({ pricePerPage: 1 });
    }
});

app.post('/api/admin/settings', verifyToken, async (req, res) => {
    try {
        if (req.user.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
        const { pricePerPage } = req.body;
        if (!pricePerPage || pricePerPage <= 0) return res.status(400).json({ error: 'Invalid price' });
        let s = await Settings.findOne() || new Settings();
        s.pricePerPage = pricePerPage;
        await s.save();
        res.json({ message: 'Settings updated', settings: s });
    } catch (err) {
        res.status(500).json({ error: 'Error updating settings' });
    }
});

// ════════════════════════════════════════════════════════════════════════════
//  PRINT AGENT ROUTES  (polled by the agent running on your PC)
// ════════════════════════════════════════════════════════════════════════════
function verifyAgent(req, res, next) {
    if (req.headers['x-agent-key'] !== AGENT_KEY)
        return res.status(403).json({ error: 'Unauthorized' });
    next();
}

app.get('/api/agent/pending-jobs', verifyAgent, async (req, res) => {
    try {
        res.json(await PrintJob.find({ status: 'pending' }).sort({ createdAt: 1 }));
    } catch (err) {
        res.status(500).json({ error: 'Error fetching jobs' });
    }
});

app.post('/api/agent/update-job', verifyAgent, async (req, res) => {
    try {
        const { jobId, status } = req.body;
        await PrintJob.findByIdAndUpdate(jobId, { status });
        res.json({ message: 'Updated', jobId, status });
    } catch (err) {
        res.status(500).json({ error: 'Error updating job' });
    }
});

// ════════════════════════════════════════════════════════════════════════════
//  STATIC / HOMEPAGE
// ════════════════════════════════════════════════════════════════════════════
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
