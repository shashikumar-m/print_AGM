const express = require('express');
const multer = require('multer');
const axios = require('axios');
const path = require('path');

const PORT = process.env.PORT || 3000;

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const upload = multer({ dest: path.join(__dirname, 'uploads') });

// Point to laptop print agent via ngrok
const PRINT_AGENT_URL = process.env.PRINT_AGENT_URL || "https://beaked-unpretentiously-rebeca.ngrok-free.dev/print";

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

app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

app.listen(PORT, () => console.log("Server running"));