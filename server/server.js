const express = require('express');
const multer = require('multer');
const axios = require('axios');
const path = require('path');
const fs = require('fs');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const pdfParse = require('pdf-parse');

const PORT = process.env.PORT || 3000;
const JWT_SECRET = 'your-secret-key-change-in-production';
const PRICE_PER_PAGE = 1; // Rs. per page

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const upload = multer({ dest: path.join(__dirname, 'uploads') });

// Print agent URL
const PRINT_AGENT_URL = process.env.PRINT_AGENT_URL || "http://localhost:5000/print";

// ============ DATABASE (File-based) ============
const DB_FILE = path.join(__dirname, 'db.json');

function getDB() {
    if (!fs.existsSync(DB_FILE)) {
        const defaultDB = {
            users: [
                {
                    id: 'admin1',
                    email: 'admin@example.com',
                    password: bcrypt.hashSync('admin123', 10),
                    role: 'admin',
                    name: 'Admin'
                }
            ],
            students: [
                {
                    id: 'student1',
                    email: 'student@example.com',
                    password: bcrypt.hashSync('student123', 10),
                    role: 'student',
                    name: 'John Doe',
                    wallet: 500
                }
            ],
            printJobs: []
        };
        fs.writeFileSync(DB_FILE, JSON.stringify(defaultDB, null, 2));
        return defaultDB;
    }
    return JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
}

function saveDB(db) {
    fs.writeFileSync(DB_FILE, JSON.stringify(db, null, 2));
}

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
app.post('/api/auth/login', (req, res) => {
    const { email, password } = req.body;
    const db = getDB();
    
    const allUsers = [...db.users, ...db.students];
    const user = allUsers.find(u => u.email === email);
    
    if (!user || !bcrypt.compareSync(password, user.password)) {
        return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    const token = jwt.sign(
        { id: user.id, email: user.email, role: user.role, name: user.name },
        JWT_SECRET
    );
    
    res.json({ token, user: { id: user.id, email: user.email, role: user.role, name: user.name, wallet: user.wallet } });
});

app.post('/api/auth/register', (req, res) => {
    const { email, password, name } = req.body;
    const db = getDB();
    
    const allUsers = [...db.users, ...db.students];
    if (allUsers.find(u => u.email === email)) {
        return res.status(400).json({ error: 'Email already exists' });
    }
    
    const newStudent = {
        id: 'student_' + Date.now(),
        email,
        password: bcrypt.hashSync(password, 10),
        role: 'student',
        name,
        wallet: 0
    };
    
    db.students.push(newStudent);
    saveDB(db);
    
    res.json({ message: 'Student registered successfully' });
});

// ============ ADMIN ROUTES ============
app.get('/api/admin/students', verifyToken, (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
    
    const db = getDB();
    res.json(db.students);
});

app.post('/api/admin/add-wallet', verifyToken, (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
    
    const { studentId, amount } = req.body;
    const db = getDB();
    
    const student = db.students.find(s => s.id === studentId);
    if (!student) return res.status(404).json({ error: 'Student not found' });
    
    student.wallet += amount;
    saveDB(db);
    
    res.json({ message: 'Wallet updated', wallet: student.wallet });
});

app.get('/api/admin/print-jobs', verifyToken, (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Unauthorized' });
    
    const db = getDB();
    res.json(db.printJobs);
});

// ============ STUDENT ROUTES ============
app.get('/api/student/wallet', verifyToken, (req, res) => {
    if (req.user.role !== 'student') return res.status(403).json({ error: 'Unauthorized' });
    
    const db = getDB();
    const student = db.students.find(s => s.id === req.user.id);
    
    if (!student) return res.status(404).json({ error: 'Student not found' });
    res.json({ wallet: student.wallet });
});

// ============ UPLOAD & COUNT PAGES ============
async function countPages(filePath) {
    const fileBuffer = fs.readFileSync(filePath);
    const data = await pdfParse(fileBuffer);
    return data.numpages;
}

app.post('/api/upload', verifyToken, upload.single('pdf'), async (req, res) => {
    try {
        if (req.user.role !== 'student') return res.status(403).json({ error: 'Only students can upload' });
        
        const filePath = req.file.path;
        const pages = await countPages(filePath);
        const cost = pages * PRICE_PER_PAGE;
        
        const db = getDB();
        const student = db.students.find(s => s.id === req.user.id);
        
        if (!student) return res.status(404).json({ error: 'Student not found' });
        if (student.wallet < cost) {
            fs.unlinkSync(filePath);
            return res.status(402).json({ error: `Insufficient wallet. Need Rs.${cost}, Have Rs.${student.wallet}` });
        }
        
        // Deduct from wallet
        student.wallet -= cost;
        
        // Record print job
        const printJob = {
            id: 'job_' + Date.now(),
            studentId: req.user.id,
            studentName: req.user.name,
            fileName: req.file.originalname,
            pages: pages,
            cost: cost,
            status: 'pending',
            createdAt: new Date(),
            duplex: req.body.duplex === 'true'
        };
        db.printJobs.push(printJob);
        saveDB(db);
        
        // Send to print agent
        const fileUrl = `https://print-agm.onrender.com/uploads/${req.file.filename}`;
        
        try {
            await axios.post(PRINT_AGENT_URL, {
                fileUrl,
                duplex: req.body.duplex === 'true'
            });
            printJob.status = 'printing';
        } catch (err) {
            printJob.status = 'failed';
            console.error('Print agent error:', err.message);
        }
        
        saveDB(db);
        
        res.json({
            message: 'PDF submitted for printing',
            pages,
            cost,
            remainingWallet: student.wallet,
            jobId: printJob.id
        });
        
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Error processing PDF' });
    }
});

// ============ HOMEPAGE ============
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

app.listen(PORT, () => console.log(`Server running on port ${PORT}`));