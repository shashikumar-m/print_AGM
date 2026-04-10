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
        // ✅ FIXED URL
        const fileUrl = `https://print-agm.onrender.com/uploads/${req.file.filename}`;

        const { duplex } = req.body;

        await axios.post(PRINT_AGENT_URL, {
            fileUrl,
            duplex: duplex === 'true'
        });

        res.send("Print request sent!");
    } catch (err) {
        console.error(err);
        res.status(500).send("Error printing");
    }
});


app.post('/print', async (req, res) => {
    try {
        const { fileUrl, duplex } = req.body;

        console.log("Printing file:", fileUrl);
        console.log("Duplex:", duplex);

        // TODO: Add actual printing logic here
        // Example: send to printer / download file / etc.

        res.send("Print started successfully");
    } catch (err) {
        console.error(err);
        res.status(500).send("Print failed");
    }
});


app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

app.listen(PORT, () => console.log("Server running"));