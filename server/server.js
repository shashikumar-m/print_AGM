require('dotenv').config();

const express  = require('express');
const multer   = require('multer');
const path     = require('path');
const fs       = require('fs');
const jwt      = require('jsonwebtoken');
const bcrypt   = require('bcryptjs');
const mongoose = require('mongoose');

let pdfParse = null;
try { pdfParse = require('pdf-parse'); } catch (_) {}

const PORT        = process.env.PORT        || 3000;
const JWT_SECRET  = process.env.JWT_SECRET  || 'change-me-in-production';
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/printer_system';
const SERVER_URL  = process.env.SERVER_URL  || `http://localhost:${PORT}`;

const UPLOADS_DIR = path.join(__dirname, 'uploads');
if (!fs.existsSync(UPLOADS_DIR)) fs.mkdirSync(UPLOADS_DIR, { recursive: true });

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));
app.use('/uploads', express.static(UPLOADS_DIR));
const upload = multer({ dest: UPLOADS_DIR });

mongoose.connect(MONGODB_URI)
    .then(() => console.log('✅ MongoDB connected'))
    .catch(err => console.error('❌ MongoDB error:', err.message));

// ════════════════════════════════════════════════════════════════════════════
//  SCHEMAS
// ════════════════════════════════════════════════════════════════════════════
const userSchema = new mongoose.Schema({
    email:      { type: String, unique: true, required: true },
    password:   { type: String, required: true },
    role:       { type: String, enum: ['admin', 'student', 'faculty'], default: 'student' },
    name:       String,
    section:    String,
    department: String,
    wallet:     { type: Number, default: 0 },
    isFaculty:  { type: Boolean, default: false },
    assignedPrinterId: String,   // override printer for this specific user
    createdAt:  { type: Date, default: Date.now }
});

const sectionSchema = new mongoose.Schema({
    name:              { type: String, required: true, unique: true },
    assignedPrinterId: String,   // default printer for all students in this section
    createdAt:         { type: Date, default: Date.now }
});

// Printer Location — each physical printer in the college
const printerLocationSchema = new mongoose.Schema({
    name:        { type: String, required: true },  // e.g. "HOD Room", "Lab 1", "Library"
    description: String,                             // e.g. "Ground floor, near reception"
    agentKey:    { type: String, required: true, unique: true }, // secret key for that PC's agent
    isOnline:    { type: Boolean, default: false },  // updated by agent heartbeat
    lastSeen:    Date,
    createdAt:   { type: Date, default: Date.now }
});

const settingsSchema = new mongoose.Schema({
    pricePerPage:       { type: Number, default: 1 },
    allowColor:         { type: Boolean, default: true },
    allowDuplex:        { type: Boolean, default: true },
    allowPageRange:     { type: Boolean, default: true },
    allowPagesPerSheet: { type: Boolean, default: true },
    maxPagesPerJob:     { type: Number, default: 0 }
});

const printJobSchema = new mongoose.Schema({
    userId:          String,
    userName:        String,
    userSection:     String,
    userRole:        { type: String, default: 'student' },
    fileName:        String,
    pages:           Number,
    cost:            Number,
    status:          { type: String, enum: ['pending','printing','completed','failed'], default: 'pending' },
    duplex:          { type: Boolean, default: false },
    colorMode:       { type: String, enum: ['bw','color'], default: 'bw' },
    pageRangeFrom:   { type: Number, default: 0 },
    pageRangeTo:     { type: Number, default: 0 },
    pagesPerSheet:   { type: Number, default: 1 },
    printerLocationId: String,   // which printer to send to
    printerLocationName: String,
    fileUrl:         String,
    fileData:        Buffer,
    createdAt:       { type: Date, default: Date.now }
});

const User            = mongoose.model('User',            userSchema);
const Section         = mongoose.model('Section',         sectionSchema);
const PrinterLocation = mongoose.model('PrinterLocation', printerLocationSchema);
const Settings        = mongoose.model('Settings',        settingsSchema);
const PrintJob        = mongoose.model('PrintJob',        printJobSchema);

// ── Seed ─────────────────────────────────────────────────────────────────────
async function initDB() {
    try {
        if (!await User.findOne({ role: 'admin' }))
            await User.create({ email:'admin', password:bcrypt.hashSync('123456',10), role:'admin', name:'Admin' });
        if (!await Settings.findOne())
            await Settings.create({});
        if (await Section.countDocuments() === 0)
            await Section.insertMany([{name:'CSE'},{name:'ECE'},{name:'MECH'},{name:'CIVIL'}]);
        // Default printer location (the main student printer)
        if (await PrinterLocation.countDocuments() === 0)
            await PrinterLocation.create({
                name: 'Main Printer',
                description: 'Student printing room',
                agentKey: 'printhub-agent-secret'
            });
    } catch (err) { console.log('initDB:', err.message); }
}
initDB();

// ── Middleware ────────────────────────────────────────────────────────────────
function verifyToken(req, res, next) {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ error: 'No token' });
    try { req.user = jwt.verify(token, JWT_SECRET); next(); }
    catch { res.status(403).json({ error: 'Invalid token' }); }
}

function requireAdmin(req, res, next) {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
    next();
}

async function countPages(filePath) {
    try {
        if (pdfParse) {
            const data = await pdfParse(fs.readFileSync(filePath));
            if (data && data.numpages) return data.numpages;
        }
    } catch (_) {}
    try {
        const m = fs.readFileSync(filePath,'binary').match(/\/Count\s+(\d+)/);
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
            { id:user._id, email:user.email, role:user.role, name:user.name },
            JWT_SECRET
        );
        res.json({ token, user: {
            id:user._id, email:user.email, role:user.role, name:user.name,
            wallet:user.wallet, section:user.section, department:user.department
        }});
    } catch { res.status(500).json({ error: 'Login error' }); }
});

// ════════════════════════════════════════════════════════════════════════════
//  PRINTER LOCATIONS  (public — needed for faculty to choose printer)
// ════════════════════════════════════════════════════════════════════════════
app.get('/api/printer-locations', async (req, res) => {
    try {
        // Return locations without agentKey (security)
        res.json(await PrinterLocation.find().select('-agentKey').sort({ name: 1 }));
    } catch { res.status(500).json({ error: 'Error fetching printer locations' }); }
});

// Admin: full CRUD for printer locations
app.get('/api/admin/printer-locations', verifyToken, requireAdmin, async (req, res) => {
    try { res.json(await PrinterLocation.find().sort({ name: 1 })); }
    catch { res.status(500).json({ error: 'Error' }); }
});

app.post('/api/admin/printer-locations', verifyToken, requireAdmin, async (req, res) => {
    try {
        const { name, description } = req.body;
        if (!name) return res.status(400).json({ error: 'Name required' });
        // Generate a unique agent key for this location
        const agentKey = 'agent-' + Math.random().toString(36).slice(2) + Date.now().toString(36);
        const loc = await PrinterLocation.create({ name, description, agentKey });
        res.json(loc);
    } catch (e) {
        if (e.code === 11000) return res.status(400).json({ error: 'Location already exists' });
        res.status(500).json({ error: 'Error creating location' });
    }
});

app.delete('/api/admin/printer-locations/:id', verifyToken, requireAdmin, async (req, res) => {
    try {
        await PrinterLocation.findByIdAndDelete(req.params.id);
        res.json({ message: 'Deleted' });
    } catch { res.status(500).json({ error: 'Error' }); }
});

// ════════════════════════════════════════════════════════════════════════════
//  SECTIONS
// ════════════════════════════════════════════════════════════════════════════
app.get('/api/sections', async (req, res) => {
    try { res.json(await Section.find().sort({ name: 1 })); }
    catch { res.status(500).json({ error: 'Error fetching sections' }); }
});

app.post('/api/admin/sections', verifyToken, requireAdmin, async (req, res) => {
    try {
        const { name } = req.body;
        if (!name?.trim()) return res.status(400).json({ error: 'Section name required' });
        if (await Section.findOne({ name: name.trim().toUpperCase() }))
            return res.status(400).json({ error: 'Section already exists' });
        res.json(await Section.create({ name: name.trim().toUpperCase() }));
    } catch { res.status(500).json({ error: 'Error creating section' }); }
});

app.delete('/api/admin/sections/:id', verifyToken, requireAdmin, async (req, res) => {
    try { await Section.findByIdAndDelete(req.params.id); res.json({ message: 'Deleted' }); }
    catch { res.status(500).json({ error: 'Error' }); }
});

// Assign printer to a section (all students in that section use this printer)
app.post('/api/admin/sections/:id/assign-printer', verifyToken, requireAdmin, async (req, res) => {
    try {
        const { printerId } = req.body;
        await Section.findByIdAndUpdate(req.params.id, { assignedPrinterId: printerId || '' });
        res.json({ message: 'Printer assigned to section' });
    } catch { res.status(500).json({ error: 'Error' }); }
});

// Assign printer to a specific user (overrides section default)
app.post('/api/admin/users/:id/assign-printer', verifyToken, requireAdmin, async (req, res) => {
    try {
        const { printerId } = req.body;
        await User.findByIdAndUpdate(req.params.id, { assignedPrinterId: printerId || '' });
        res.json({ message: 'Printer assigned to user' });
    } catch { res.status(500).json({ error: 'Error' }); }
});

// ════════════════════════════════════════════════════════════════════════════
//  UPLOAD  (students + faculty)
// ════════════════════════════════════════════════════════════════════════════
app.post('/api/upload', verifyToken, upload.single('pdf'), async (req, res) => {
    try {
        const role = req.user.role;
        if (role !== 'student' && role !== 'faculty')
            return res.status(403).json({ error: 'Only students and faculty can upload' });
        if (!req.file) return res.status(400).json({ error: 'No file uploaded' });

        const filePath    = req.file.path;
        const totalPages  = await countPages(filePath);
        const colorMode   = req.body.colorMode   || 'bw';
        const duplex      = req.body.duplex      === 'true';
        const pagesPerSheet = parseInt(req.body.pagesPerSheet) || 1;
        const pageFrom    = parseInt(req.body.pageFrom) || 0;
        const pageTo      = parseInt(req.body.pageTo)   || 0;
        const printerLocationId = req.body.printerLocationId || '';

        let effectivePages = totalPages;
        if (pageFrom > 0 && pageTo >= pageFrom) effectivePages = pageTo - pageFrom + 1;
        const paperSheets = Math.ceil(effectivePages / pagesPerSheet);

        const settings     = await Settings.findOne();
        const pricePerPage = settings?.pricePerPage || 1;

        // Permission checks (only for students)
        if (role === 'student') {
            if (!settings?.allowColor && colorMode === 'color')
                return res.status(403).json({ error: 'Color printing is not allowed' });
            if (!settings?.allowDuplex && duplex)
                return res.status(403).json({ error: 'Duplex printing is not allowed' });
            if (!settings?.allowPageRange && (pageFrom > 0 || pageTo > 0))
                return res.status(403).json({ error: 'Custom page range is not allowed' });
            if (!settings?.allowPagesPerSheet && pagesPerSheet > 1)
                return res.status(403).json({ error: 'Multiple pages per sheet is not allowed' });
            if (settings?.maxPagesPerJob > 0 && effectivePages > settings.maxPagesPerJob)
                return res.status(403).json({ error: `Max ${settings.maxPagesPerJob} pages per job` });
        }

        // Cost: faculty = free, students = wallet deduction
        let cost = 0;
        let remainingWallet = 0;

        if (role === 'student') {
            cost = paperSheets * pricePerPage;
            const student = await User.findById(req.user.id);
            if (!student) return res.status(404).json({ error: 'Student not found' });
            if (student.wallet < cost) {
                fs.unlinkSync(filePath);
                return res.status(402).json({ error: `Insufficient balance. Need ₹${cost}, have ₹${student.wallet}` });
            }
            student.wallet -= cost;
            await student.save();
            remainingWallet = student.wallet;
        }

        // Resolve printer location:
        // Priority: 1) user explicitly chose one  2) user's assigned printer  3) section's printer  4) default
        let resolvedPrinterId = printerLocationId || '';
        let locationName = 'Main Printer';

        if (!resolvedPrinterId) {
            // Auto-resolve from user or section assignment
            const userDoc = await User.findById(req.user.id);
            if (userDoc?.assignedPrinterId) {
                resolvedPrinterId = userDoc.assignedPrinterId;
            } else if (userDoc?.section) {
                const sec = await Section.findOne({ name: userDoc.section });
                if (sec?.assignedPrinterId) resolvedPrinterId = sec.assignedPrinterId;
            }
        }

        if (resolvedPrinterId) {
            const loc = await PrinterLocation.findById(resolvedPrinterId).select('name');
            if (loc) locationName = loc.name;
        }

        const fileData = fs.readFileSync(filePath);
        const user     = await User.findById(req.user.id);

        const printJob = await new PrintJob({
            userId:              req.user.id,
            userName:            req.user.name,
            userSection:         user?.section || user?.department || '',
            userRole:            role,
            fileName:            req.file.originalname,
            pages:               effectivePages,
            cost,
            status:              'pending',
            duplex, colorMode,
            pageRangeFrom:       pageFrom,
            pageRangeTo:         pageTo,
            pagesPerSheet,
            printerLocationId:   resolvedPrinterId,
            printerLocationName: locationName,
            fileUrl:             'pending',
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
            remainingWallet,
            jobId:           printJob._id,
            printerLocation: locationName
        });
    } catch (err) {
        console.error('Upload error:', err);
        res.status(500).json({ error: 'Error processing PDF' });
    }
});

// ════════════════════════════════════════════════════════════════════════════
//  STUDENT
// ════════════════════════════════════════════════════════════════════════════
app.get('/api/student/wallet', verifyToken, async (req, res) => {
    try {
        if (req.user.role !== 'student') return res.status(403).json({ error: 'Unauthorized' });
        const student = await User.findById(req.user.id);
        if (!student) return res.status(404).json({ error: 'Not found' });
        res.json({ wallet: student.wallet });
    } catch { res.status(500).json({ error: 'Error' }); }
});

// ════════════════════════════════════════════════════════════════════════════
//  ADMIN — Users
// ════════════════════════════════════════════════════════════════════════════
app.get('/api/admin/students', verifyToken, requireAdmin, async (req, res) => {
    try { res.json(await User.find({ role: 'student' }).select('-password')); }
    catch { res.status(500).json({ error: 'Error' }); }
});

app.post('/api/admin/students', verifyToken, requireAdmin, async (req, res) => {
    try {
        const { name, email, password, section, wallet } = req.body;
        if (!name || !email || !password) return res.status(400).json({ error: 'Name, email and password required' });
        if (await User.findOne({ email })) return res.status(400).json({ error: 'Email already exists' });
        const s = await new User({ email, password:bcrypt.hashSync(password,10), role:'student', name, section:section||'', wallet:parseInt(wallet)||0 }).save();
        res.json({ message:'Student created', student:{ id:s._id, name:s.name, email:s.email, section:s.section, wallet:s.wallet } });
    } catch { res.status(500).json({ error: 'Error creating student' }); }
});

app.get('/api/admin/faculty', verifyToken, requireAdmin, async (req, res) => {
    try { res.json(await User.find({ role: 'faculty' }).select('-password')); }
    catch { res.status(500).json({ error: 'Error' }); }
});

app.post('/api/admin/faculty', verifyToken, requireAdmin, async (req, res) => {
    try {
        const { name, email, password, department, printerLocationId } = req.body;
        if (!name || !email || !password) return res.status(400).json({ error: 'Name, email and password required' });
        if (await User.findOne({ email })) return res.status(400).json({ error: 'Email already exists' });
        const f = await new User({
            email, password:bcrypt.hashSync(password,10),
            role:'faculty', name,
            department: department || '',
            section: printerLocationId || '',  // reuse section field to store assigned printer
            wallet: 0, isFaculty: true
        }).save();
        res.json({ message:'Faculty created', faculty:{ id:f._id, name:f.name, email:f.email, department:f.department } });
    } catch { res.status(500).json({ error: 'Error creating faculty' }); }
});

app.post('/api/admin/add-wallet', verifyToken, requireAdmin, async (req, res) => {
    try {
        const { studentId, amount } = req.body;
        const student = await User.findById(studentId);
        if (!student) return res.status(404).json({ error: 'Student not found' });
        student.wallet += parseInt(amount);
        await student.save();
        res.json({ message:'Wallet updated', wallet:student.wallet });
    } catch { res.status(500).json({ error: 'Error' }); }
});

app.get('/api/admin/print-jobs', verifyToken, requireAdmin, async (req, res) => {
    try { res.json(await PrintJob.find().select('-fileData').sort({ createdAt: -1 })); }
    catch { res.status(500).json({ error: 'Error' }); }
});

// ════════════════════════════════════════════════════════════════════════════
//  SETTINGS
// ════════════════════════════════════════════════════════════════════════════
app.get('/api/settings', async (req, res) => {
    try {
        let s = await Settings.findOne();
        if (!s) s = await Settings.create({});
        res.json(s);
    } catch { res.json({ pricePerPage:1 }); }
});

app.post('/api/admin/settings', verifyToken, requireAdmin, async (req, res) => {
    try {
        const { pricePerPage, allowColor, allowDuplex, allowPageRange, allowPagesPerSheet, maxPagesPerJob } = req.body;
        if (pricePerPage !== undefined && pricePerPage <= 0) return res.status(400).json({ error: 'Invalid price' });
        let s = await Settings.findOne() || new Settings();
        if (pricePerPage       !== undefined) s.pricePerPage       = pricePerPage;
        if (allowColor         !== undefined) s.allowColor         = allowColor;
        if (allowDuplex        !== undefined) s.allowDuplex        = allowDuplex;
        if (allowPageRange     !== undefined) s.allowPageRange     = allowPageRange;
        if (allowPagesPerSheet !== undefined) s.allowPagesPerSheet = allowPagesPerSheet;
        if (maxPagesPerJob     !== undefined) s.maxPagesPerJob     = maxPagesPerJob;
        await s.save();
        res.json({ message:'Settings updated', settings:s });
    } catch { res.status(500).json({ error: 'Error' }); }
});

// ════════════════════════════════════════════════════════════════════════════
//  PRINT AGENT  — each location has its own agentKey
// ════════════════════════════════════════════════════════════════════════════
async function getLocationByKey(key) {
    return PrinterLocation.findOne({ agentKey: key });
}

// Agent heartbeat — marks location as online
app.post('/api/agent/heartbeat', async (req, res) => {
    try {
        const key = req.headers['x-agent-key'];
        if (!key) return res.status(403).json({ error: 'No key' });
        const loc = await getLocationByKey(key);
        if (!loc) return res.status(403).json({ error: 'Unknown agent key' });
        await PrinterLocation.findByIdAndUpdate(loc._id, { isOnline:true, lastSeen:new Date() });
        res.json({ ok:true, locationName:loc.name });
    } catch { res.status(500).json({ error: 'Error' }); }
});

// Agent polls for jobs assigned to its location
app.get('/api/agent/pending-jobs', async (req, res) => {
    try {
        const key = req.headers['x-agent-key'];
        if (!key) return res.status(403).json({ error: 'No key' });
        const loc = await getLocationByKey(key);
        if (!loc) return res.status(403).json({ error: 'Unknown agent key' });

        // Update heartbeat
        await PrinterLocation.findByIdAndUpdate(loc._id, { isOnline:true, lastSeen:new Date() });

        // Return pending jobs for this location
        // If printerLocationId is empty, it goes to the default (first) location
        const defaultLoc = await PrinterLocation.findOne().sort({ createdAt: 1 });
        const query = {
            status: 'pending',
            $or: [
                { printerLocationId: loc._id.toString() },
                // Jobs with no location go to default printer
                ...(loc._id.toString() === defaultLoc?._id.toString()
                    ? [{ printerLocationId: { $in: ['', null, undefined] } }]
                    : [])
            ]
        };
        res.json(await PrintJob.find(query).select('-fileData').sort({ createdAt: 1 }));
    } catch { res.status(500).json({ error: 'Error' }); }
});

app.get('/api/agent/download-job/:jobId', async (req, res) => {
    try {
        const key = req.headers['x-agent-key'];
        if (!key || !await getLocationByKey(key)) return res.status(403).json({ error: 'Unauthorized' });
        const job = await PrintJob.findById(req.params.jobId).select('fileData fileName');
        if (!job || !job.fileData) return res.status(404).json({ error: 'File not found' });
        res.set('Content-Type', 'application/pdf');
        res.set('Content-Disposition', `attachment; filename="${job.fileName}"`);
        res.send(job.fileData);
    } catch { res.status(500).json({ error: 'Error' }); }
});

app.post('/api/agent/update-job', async (req, res) => {
    try {
        const key = req.headers['x-agent-key'];
        if (!key || !await getLocationByKey(key)) return res.status(403).json({ error: 'Unauthorized' });
        const { jobId, status } = req.body;
        await PrintJob.findByIdAndUpdate(jobId, { status });
        res.json({ message:'Updated', jobId, status });
    } catch { res.status(500).json({ error: 'Error' }); }
});

app.get('/', (req, res) => res.sendFile(path.join(__dirname, 'public', 'index.html')));
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
