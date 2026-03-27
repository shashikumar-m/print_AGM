const express = require('express');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const { print } = require('pdf-to-printer');

const app = express();
app.use(express.json());

app.post('/print', async (req, res) => {
    try {
        console.log("🔥 PRINT REQUEST RECEIVED");
        console.log(req.body);

        const { fileUrl, duplex } = req.body;

        const filePath = path.join(__dirname, 'temp.pdf');

        console.log("⬇️ Downloading from:", fileUrl);

        const response = await axios({
            url: fileUrl,
            method: 'GET',
            responseType: 'stream'
        });

        const writer = fs.createWriteStream(filePath);
        response.data.pipe(writer);

        writer.on('finish', async () => {
            console.log("✅ File downloaded");

            await print(filePath, {
                duplex: duplex ? 'long-edge' : 'simplex'
            });

            console.log("🖨️ Printing done");

            res.send("Printed successfully");
        });

    } catch (err) {
        console.error("❌ ERROR:", err.message);
        res.status(500).send("Print failed");
    }
});


app.listen(5000, () => console.log("Print Agent running on 5000"));