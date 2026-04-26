// Load environment variables first
require('dotenv').config();

const express = require('express');
const multer = require('multer');
const axios = require('axios');
const path = require('path');
const fs = require('fs');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');

// Import pdf-parse correctly
let pdfParse;
try {
    pdfParse = require('pdf-parse/lib/pdf.js');
} catch (e) {
    try {
        pdfParse = require('pdf-parse');
    } catch (err) {
        console.warn('pdf-parse not available, using page count fallback');
        pdfParse = null;
    }
}

const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/printer_system';

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const upload = multer({ dest: path.join(__dirname, 'uploads') });

// Print agent URL
const PRINT_AGENT_URL = process.env.PRINT_AGENT_URL || "http://localhost:5000/print";

// ============ CONNECTION ============
mongoose.connect(MONGODB_URI)
    .then(() => console.log('✅ MongoDB connected'))
    .catch(err => {
        console.error('❌ MongoDB connection error:', err);
        console.log('Using fallback file-based DB');
    });

// ============ MONGOOSE SCHEMAS ============
const userSchema = new mongoose.Schema({
    email: { type: String, unique: true, required: true },
    password: { type: String, required: true },
    role: { type: String, enum: ['admin', 'student'], default: 'student' },
    name: String,
    wallet: { type: Number, default: 0 },
    createdAt: { type: Date, default: Date.now }
});

const settingsSchema = new mongoose.Schema({
    pricePerPage: { type: Number, default: 1 }
});

const printJobSchema = new mongoose.Schema({
    studentId: String,
    studentName: String,
    fileName: String,
    pages: Number,
    cost: Number,
    status: { type: String, enum: ['pending', 'printing', 'completed', 'failed'], default: 'pending' },
    duplex: Boolean,
    fileUrl: String,
    createdAt: { type: Date, default: Date.now }
});

const User = mongoose.model('User', userSchema);
const Settings = mongoose.model('Settings', settingsSchema);
const PrintJob = mongoose.model('PrintJob', printJobSchema);

// ============ INIT DB ============
async function initDB() {
    try {
        const adminExists = await User.findOne({ email: 'admin@example.com' });
        if (!adminExists) {
            await User.create({
                email: 'admin@example.com',
                password: bcrypt.hashSync('admin123', 10),
                role: 'admin',
                name: 'Admin'
            });
        }

        const studentExists = await User.findOne({ email: 'student@example.com' });
        if (!studentExists) {
            await User.create({
                email: 'student@example.com',
                password: bcrypt.hashSync('student123', 10),
                role: 'student',
                name: 'John Doe',
                wallet: 500
            });
        }

        const settingsExists = await Settings.findOne();
        if (!settingsExists) {
            await Settings.create({ pricePerPage: 1 });
        }
    } catch (err) {
        console.log('Init DB error (might be offline):', err.message);
    }
}

initDB();

// ============ MIDDLEWARE ============
const verifyToken = (req, res, next) => {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ error: 'No token' });
    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded;
        next();
    } catch (err) {
        res.status(403).json({ error: 'Invalid token' });
    }
};

// ============ AUTH ROUTES ============
app.post('/api/auth/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        const user = await User.findOne({ email });
        
        if (!user || !bcrypt.compareSync(password, user.password)) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        
        const token = jwt.sign(
            { id: user._id, email: user.email, role: user.role, name: user.name },
            JWT_SECRET
        );
        
        res.json({ 
            token, 
            user: { 
                id: user._id, 
                email: user.email, 
                role: user.role, 
                name: user.name, 
                wallet: user.wallet 
            } 
        });
    } catch (err) {
        res.status(500).json({ error: 'Login error' });
    }
});

app.post('/api/auth/register', async (req, res) => {
    try {
        const { email, password, name } = req.body;
        
        const existingUser = await User.findOne({ email });
        if (existingUser) {
            return res.status(400).json({ error: 'Email already exists' });
        }
        
        const newStudent = new User({
            email,
            password: bcrypt.hashSync(password, 10),
            role: 'student',
            name,
            wallet: 0
        });
        
        await newStudent.save();
        res.json({ message: 'Student registered successfully' });
    } catch (err) {
        res.status(500).json({ error: 'Registration error' });
    }
});

// ============ ADMIN ROUTES ============
app.get('/api/admin/students', verifyToken, async (req, res) => {
    try {
        if (req.user.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
        
        const students = await User.find({ role: 'student' }).select('-password');
        res.json(students);
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
        
        const jobs = await PrintJob.find().sort({ createdAt: -1 });
        res.json(jobs);
    } catch (err) {
        res.status(500).json({ error: 'Error fetching print jobs' });
    }
});

// ============ SETTINGS ROUTES ============
app.get('/api/settings', async (req, res) => {
    try {
        let settings = await Settings.findOne();
        if (!settings) {
            settings = await Settings.create({ pricePerPage: 1 });
        }
        res.json(settings);
    } catch (err) {
        res.json({ pricePerPage: 1 });
    }
});

app.post('/api/admin/settings', verifyToken, async (req, res) => {
    try {
        if (req.user.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
        
        const { pricePerPage } = req.body;
        
        if (!pricePerPage || pricePerPage <= 0) {
            return res.status(400).json({ error: 'Invalid price' });
        }
        
        let settings = await Settings.findOne();
        if (!settings) {
            settings = new Settings();
        }
        settings.pricePerPage = pricePerPage;
        await settings.save();
        
        res.json({ message: 'Settings updated', settings });
    } catch (err) {
        res.status(500).json({ error: 'Error updating settings' });
    }
});

// ============ STUDENT ROUTES ============
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

// ============ UPLOAD & COUNT PAGES ============
async function countPages(filePath) {
    try {
        const fileBuffer = fs.readFileSync(filePath);
        
        // Try using pdfParse if available
        if (pdfParse) {
            try {
                const data = await pdfParse(fileBuffer);
                return data.numpages || 1;
            } catch (err) {
                console.log('pdfParse error, using fallback');
            }
        }
        
        // Fallback: count /Pages in PDF
        const text = fileBuffer.toString('binary');
        const pageMatches = text.match(/\/Type\s*\/Pages[\s\S]*?\/Count\s+(\d+)/);
        if (pageMatches && pageMatches[1]) {
            return parseInt(pageMatches[1]);
        }
        
        // Last resort: estimate 1 page per ~5KB
        return Math.max(1, Math.ceil(fileBuffer.length / 5000));
    } catch (err) {
        console.error('Error counting pages:', err);
        return 1; // Default to 1 page
    }
}

app.post('/api/upload', verifyToken, upload.single('pdf'), async (req, res) => {
    try {
        if (req.user.role !== 'student') return res.status(403).json({ error: 'Only students can upload' });
        
        const filePath = req.file.path;
        const pages = await countPages(filePath);
        
        // Get dynamic price from settings
        const settings = await Settings.findOne();
        const pricePerPage = settings?.pricePerPage || 1;
        const cost = pages * pricePerPage;
        
        const student = await User.findById(req.user.id);
        
        if (!student) return res.status(404).json({ error: 'Student not found' });
        if (student.wallet < cost) {
            fs.unlinkSync(filePath);
            return res.status(402).json({ error: `Insufficient wallet. Need Rs.${cost}, Have Rs.${student.wallet}` });
        }
        
        // Deduct from wallet
        student.wallet -= cost;
        await student.save();
        
        // Record print job
        const printJob = new PrintJob({
            studentId: req.user.id,
            studentName: req.user.name,
            fileName: req.file.originalname,
            pages: pages,
            cost: cost,
            status: 'pending',
            duplex: req.body.duplex === 'true',
            fileUrl: `${process.env.SERVER_URL || `http://localhost:${PORT}`}/uploads/${req.file.filename}`
        });
        await printJob.save();

        // Try to notify print agent if configured (optional, agent also polls)
        if (process.env.PRINT_AGENT_URL) {
            try {
                await axios.post(process.env.PRINT_AGENT_URL, {
                    jobId: printJob._id,
                    fileUrl: printJob.fileUrl,
                    duplex: req.body.duplex === 'true'
                }, { timeout: 5000 });
                printJob.status = 'printing';
                await printJob.save();
            } catch (err) {
                // Agent not reachable — job stays 'pending', agent will poll and pick it up
                console.log('Print agent not reachable, job queued as pending:', err.message);
            }
        }
        
        res.json({
            message: 'PDF submitted for printing',
            pages,
            cost,
            remainingWallet: student.wallet,
            jobId: printJob._id
        });
        
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Error processing PDF' });
    }
});

// ============ PRINT AGENT ROUTES ============
// Agent polls this to get pending jobs
app.get('/api/agent/pending-jobs', async (req, res) => {
    try {
        const agentKey = req.headers['x-agent-key'];
        if (agentKey !== (process.env.AGENT_KEY || 'printhub-agent-secret')) {
            return res.status(403).json({ error: 'Unauthorized' });
        }
        const jobs = await PrintJob.find({ status: 'pending' }).sort({ createdAt: 1 });
        res.json(jobs);
    } catch (err) {
        res.status(500).json({ error: 'Error fetching pending jobs' });
    }
});

// Agent calls this to update job status
app.post('/api/agent/update-job', async (req, res) => {
    try {
        const agentKey = req.headers['x-agent-key'];
        if (agentKey !== (process.env.AGENT_KEY || 'printhub-agent-secret')) {
            return res.status(403).json({ error: 'Unauthorized' });
        }
        const { jobId, status } = req.body;
        await PrintJob.findByIdAndUpdate(jobId, { status });
        res.json({ message: 'Job updated', jobId, status });
    } catch (err) {
        res.status(500).json({ error: 'Error updating job' });
    }
});

// ============ HOMEPAGE ============
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

app.listen(PORT, () => console.log(`Server running on port ${PORT}`));