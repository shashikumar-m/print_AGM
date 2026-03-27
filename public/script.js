document.getElementById('uploadForm').addEventListener('submit', async (e) => {
    e.preventDefault();

    const formData = new FormData(e.target);

    const duplex = formData.get('duplex') ? true : false;
    formData.append('duplex', duplex);

    const res = await fetch('/upload', {
        method: 'POST',
        body: formData
    });

    const text = await res.text();
    alert(text);
});