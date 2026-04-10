const express = require('express');
const multer = require('multer');
const axios = require('axios');
const path = require('path');

const PORT = process.env.PORT || 3000;

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const upload = multer({ dest: path.join(__dirname, 'uploads') });

const PRINT_AGENT_URL = "https://print-agm.onrender.com/print";

// ✅ Homepage fix
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.post('/upload', upload.single('pdf'), async (req, res) => {
    try {
        const fileUrl = `https://print-agm.onrender.com/uploads/${req.file.filename}`;
        const { duplex } = req.body;

        console.log("Printing file:", fileUrl);
        console.log("Duplex:", duplex === 'true');

        res.send("Print request processed!");
    } catch (err) {
        console.error(err);
        res.status(500).send("Error printing");
    }
});



app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

app.listen(PORT, () => console.log("Server running"));