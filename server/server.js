const express = require('express');
const multer = require('multer');
const axios = require('axios');
const path = require('path');

const app = express();
app.use(express.json());
app.use(express.static('public'));

const upload = multer({ dest: path.join(__dirname, 'uploads') });

// 👉 Replace with your ngrok URL
const PRINT_AGENT_URL = "https://beaked-unpretentiously-rebeca.ngrok-free.dev/print";

app.post('/upload', upload.single('pdf'), async (req, res) => {
    try {
        const fileUrl = `http://192.168.29.235:3000/uploads/${req.file.filename}`;

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

app.listen(3000, () => console.log("Server running on 3000"));