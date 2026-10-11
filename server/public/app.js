// ============================================================
//  PrintHub Web App
// ============================================================
let currentUser = null;
let token       = null;
let settings    = { pricePerPage:1, allowColor:true, allowDuplex:true, allowPageRange:true, allowPagesPerSheet:true, maxPagesPerJob:0 };
let allStudents = [];
let allSections = [];

const API = window.location.origin + '/api';

// ── Init ─────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
    const t = localStorage.getItem('token');
    if (t) {
        token = t;
        currentUser = JSON.parse(localStorage.getItem('user') || 'null');
        if (currentUser) { showDashboard(); return; }
    }
    showLoginPage();
});

// ── Helpers ───────────────────────────────────────────────────
function authHeaders() {
    return { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' };
}

function showAlert(msg, type = 'info') {
    const c = document.getElementById('alertContainer');
    if (!c) return;
    c.innerHTML = `<div class="alert alert-${type} show">${msg}</div>`;
    setTimeout(() => { if (c.firstChild) c.firstChild.classList.remove('show'); }, 4000);
}

function logout() {
    localStorage.clear();
    token = null; currentUser = null;
    showLoginPage();
}

function timeAgo(dateStr) {
    const diff = Date.now() - new Date(dateStr).getTime();
    const m = Math.floor(diff/60000);
    if (m < 1) return 'just now';
    if (m < 60) return `${m}m ago`;
    const h = Math.floor(m/60);
    if (h < 24) return `${h}h ago`;
    return `${Math.floor(h/24)}d ago`;
}

// ============================================================
//  LOGIN PAGE
// ============================================================
function showLoginPage() {
    document.getElementById('app').innerHTML = `
    <div class="auth-wrap">
      <div class="auth-card">
        <div class="auth-logo">
          <div class="college-logo-wrap">
            <img src="/images/college_logo.png" alt="AGM College Logo" class="college-logo-img">
          </div>
          <h1 class="college-name">AGM Rural College of Engineering<br>and Technology, Hubli</h1>
          <div class="printhub-badge">
            <span class="printhub-icon">🖨️</span>
            <span class="printhub-label">PrintHub</span>
          </div>
          <p class="auth-tagline">Smart Student Printing System</p>
        </div>
        <form id="loginForm">
          <h2>Sign In</h2>
          <div class="form-group">
            <label>Username / Email</label>
            <input type="text" id="loginEmail" required placeholder="Enter username or email" autocomplete="username">
          </div>
          <div class="form-group">
            <label>Password</label>
            <div class="input-icon-wrap">
              <input type="password" id="loginPassword" required placeholder="Enter password" autocomplete="current-password">
              <span class="toggle-pass" onclick="togglePass('loginPassword',this)">👁</span>
            </div>
          </div>
          <button type="submit" class="btn btn-primary" id="loginBtn">Sign In</button>
        </form>
        <div class="auth-hint" style="display:none"></div>
        <div class="auth-toggle" style="display:none"></div>
      </div>
    </div>
    <div id="alertContainer"></div>`;

    document.getElementById('loginForm').addEventListener('submit', async e => {
        e.preventDefault();
        const btn = document.getElementById('loginBtn');
        btn.disabled = true; btn.textContent = 'Signing in…';
        try {
            const r = await fetch(API + '/auth/login', {
                method:'POST', headers:{'Content-Type':'application/json'},
                body: JSON.stringify({ email: document.getElementById('loginEmail').value.trim(), password: document.getElementById('loginPassword').value })
            });
            const d = await r.json();
            if (r.ok) {
                token = d.token; currentUser = d.user;
                localStorage.setItem('token', token);
                localStorage.setItem('user', JSON.stringify(currentUser));
                showDashboard();
            } else { showAlert(d.error || 'Login failed', 'error'); }
        } catch { showAlert('Connection failed', 'error'); }
        btn.disabled = false; btn.textContent = 'Sign In';
    });
}

function togglePass(id, el) {
    const inp = document.getElementById(id);
    inp.type = inp.type === 'password' ? 'text' : 'password';
    el.textContent = inp.type === 'password' ? '👁' : '🙈';
}

function showDashboard() {
    if (currentUser.role === 'admin') showAdminDashboard();
    else showStudentDashboard();
}

// ============================================================
//  STUDENT / FACULTY DASHBOARD
// ============================================================
let _jobPollInterval = null;
let _printerPollInterval = null;
let _activeJobId = null;

async function showStudentDashboard() {
    await loadSettings();
    const isFaculty = currentUser.role === 'faculty';

    document.getElementById('app').innerHTML = `
    <div class="dashboard">
      <nav class="topnav">
        <div class="topnav-left">
          <img src="/images/college_logo.png" alt="AGM" class="nav-college-logo">
          <div class="nav-title-group">
            <span class="nav-college-name">AGM Rural College</span>
            <span class="nav-logo">🖨️ PrintHub</span>
          </div>
          ${currentUser.section ? `<span class="section-badge">${currentUser.section}</span>` : ''}
          ${isFaculty ? `<span class="section-badge" style="background:rgba(124,58,237,.3)">Faculty</span>` : ''}
        </div>
        <div class="topnav-right">
          <span class="nav-user">👤 ${currentUser.name}</span>
          <button class="btn btn-sm" onclick="showChangePasswordModal()" style="margin-right:6px">🔐 Password</button>
          <button class="btn-logout" onclick="logout()">Logout</button>
        </div>
      </nav>

      <div class="page-content">
        <div id="alertContainer"></div>

        <!-- Printer status banner (students only) -->
        ${!isFaculty ? `<div id="printerStatusBanner" style="margin-bottom:14px;display:none"></div>` : ''}

        <!-- Live job tracker -->
        <div id="liveJobCard" style="display:none;margin-bottom:14px"></div>

        <!-- Wallet card -->
        <div class="wallet-card" style="${isFaculty ? 'background:linear-gradient(135deg,#7c3aed,#6d28d9)' : ''}">
          <div class="wallet-label">${isFaculty ? '🎓 Faculty Account' : '💰 Wallet Balance'}</div>
          <div class="wallet-amount">${isFaculty ? '∞ Free' : '₹<span id="walletAmt">…</span>'}</div>
          <div class="wallet-sub">${isFaculty ? 'Unlimited free printing' : '₹<span id="priceDisplay">${settings.pricePerPage}</span> per page'}</div>
        </div>

        <!-- Quick actions -->
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;margin:16px 0">
          <div class="action-card" onclick="document.getElementById('uploadSection').scrollIntoView({behavior:'smooth'})">
            <div class="action-icon" style="background:#eef2ff">📄</div>
            <div class="action-label">Upload & Print</div>
          </div>
          <div class="action-card" onclick="showPrintHistory()">
            <div class="action-icon" style="background:#e0f2fe">📜</div>
            <div class="action-label">Print History</div>
          </div>
        </div>

        <!-- Print history panel (hidden by default) -->
        <div id="historyPanel" style="display:none;margin-bottom:16px">
          <div class="card">
            <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:12px">
              <h2 class="card-title" style="margin:0">📜 Print History</h2>
              <button class="btn btn-sm" onclick="document.getElementById('historyPanel').style.display='none'">✕ Close</button>
            </div>
            <div id="historyList"><div style="color:#94a3b8;font-size:13px">Loading…</div></div>
          </div>
        </div>

        <!-- Upload card -->
        <div class="card" id="uploadSection">
          <h2 class="card-title">📄 Upload PDF to Print</h2>
          <div class="file-drop" id="fileDrop" onclick="document.getElementById('pdfInput').click()">
            <input type="file" id="pdfInput" accept=".pdf" style="display:none">
            <div id="fileDropContent">
              <div class="file-drop-icon">📁</div>
              <div class="file-drop-text">Click to select PDF</div>
              <div class="file-drop-sub">PDF only · Max 50 MB</div>
            </div>
          </div>

          ${!isFaculty ? `<div class="print-options">
            <h3 class="options-title">Print Options</h3>
            ${settings.allowColor ? `
            <div class="option-row">
              <span class="option-label">🎨 Color Mode</span>
              <div class="chip-group">
                <button class="chip active" id="chip-bw"    onclick="selectChip('colorMode','bw',this)">B&amp;W</button>
                <button class="chip"        id="chip-color" onclick="selectChip('colorMode','color',this)">Color</button>
              </div>
            </div>` : ''}
            ${settings.allowDuplex ? `
            <div class="option-row">
              <span class="option-label">🔄 Duplex (Both Sides)</span>
              <label class="toggle-switch"><input type="checkbox" id="duplexCheck"><span class="toggle-slider"></span></label>
            </div>` : ''}
            ${settings.allowPagesPerSheet ? `
            <div class="option-row">
              <span class="option-label">📐 Pages per Sheet</span>
              <div class="chip-group">
                <button class="chip active" onclick="selectChip('pagesPerSheet','1',this)">1</button>
                <button class="chip"        onclick="selectChip('pagesPerSheet','2',this)">2</button>
                <button class="chip"        onclick="selectChip('pagesPerSheet','4',this)">4</button>
              </div>
            </div>` : ''}
            ${settings.allowPageRange ? `
            <div class="option-row">
              <span class="option-label">📋 Custom Page Range</span>
              <label class="toggle-switch"><input type="checkbox" id="rangeCheck" onchange="toggleRangeInputs()"><span class="toggle-slider"></span></label>
            </div>
            <div id="rangeInputs" style="display:none;" class="range-inputs">
              <input type="number" id="pageFrom" placeholder="From" min="1">
              <span>to</span>
              <input type="number" id="pageTo"   placeholder="To"   min="1">
            </div>` : ''}
            ${settings.maxPagesPerJob > 0 ? `<p class="option-note">⚠️ Max ${settings.maxPagesPerJob} pages per job</p>` : ''}
          </div>` : ''}

          ${isFaculty ? `
          <div class="print-options">
            <h3 class="options-title">🗂️ Select Section to Print For</h3>
            <div id="facultySectionList"><div style="color:#94a3b8;font-size:13px">Loading sections…</div></div>
          </div>` : ''}

          <button class="btn btn-primary btn-submit" onclick="submitPDF()">🖨️ Submit for Printing</button>
        </div>
      </div>
    </div>

    <!-- Change Password Modal -->
    <div id="changePassModal" class="modal">
      <div class="modal-box">
        <div class="modal-header">
          <h3>🔐 Change Password</h3>
          <button class="modal-close" onclick="document.getElementById('changePassModal').classList.remove('active')">✕</button>
        </div>
        <div class="form-group">
          <label>Current Password</label>
          <div class="input-icon-wrap">
            <input type="password" id="cpCurrent" placeholder="Enter current password">
            <span class="toggle-pass" onclick="togglePass('cpCurrent',this)">👁</span>
          </div>
        </div>
        <div class="form-group">
          <label>New Password</label>
          <div class="input-icon-wrap">
            <input type="password" id="cpNew" placeholder="Min 6 characters">
            <span class="toggle-pass" onclick="togglePass('cpNew',this)">👁</span>
          </div>
        </div>
        <div class="form-group">
          <label>Confirm New Password</label>
          <input type="password" id="cpConfirm" placeholder="Repeat new password">
        </div>
        <button class="btn btn-primary" onclick="submitChangePassword()">Update Password</button>
      </div>
    </div>`;

    window._printOpts = { colorMode:'bw', pagesPerSheet:'1' };
    window._chosenSectionId = '';

    if (isFaculty) {
        fetch(API+'/faculty/sections-for-printer', {headers:{'Authorization':`Bearer ${token}`}})
            .then(r => r.json())
            .then(secs => {
                const el = document.getElementById('facultySectionList');
                if (!el) return;
                if (!secs.length) {
                    el.innerHTML = `<div style="color:#f59e0b;font-size:13px;padding:12px;background:#fef3c7;border-radius:8px">⚠️ No sections assigned. Contact admin.</div>`;
                    return;
                }
                el.innerHTML = secs.map(s => `
                  <div class="section-select-item" id="sec-${s._id}" onclick="selectFacultySection('${s._id}','${s.name}',this)">
                    <div class="section-select-icon">🗂️</div>
                    <div class="section-select-name">${s.name}</div>
                    <div class="section-select-check" id="check-${s._id}" style="display:none">✅</div>
                  </div>`).join('');
            }).catch(() => {});
    }

    document.getElementById('pdfInput').addEventListener('change', e => {
        const f = e.target.files[0];
        if (!f) return;
        if (f.size > 50*1024*1024) { showAlert('File too large (max 50MB)','error'); return; }
        document.getElementById('fileDropContent').innerHTML = `
          <div class="file-drop-icon">📄</div>
          <div class="file-drop-text file-selected">${f.name}</div>
          <div class="file-drop-sub">${(f.size/1024/1024).toFixed(2)} MB</div>`;
    });

    if (!isFaculty) {
        try {
            const r = await fetch(API+'/student/wallet',{headers:{'Authorization':`Bearer ${token}`}});
            const d = await r.json();
            const el = document.getElementById('walletAmt');
            if (el) el.textContent = d.wallet ?? 0;
        } catch { const el = document.getElementById('walletAmt'); if (el) el.textContent = currentUser.wallet ?? 0; }

        // Load printer status
        loadPrinterStatus();
        _printerPollInterval = setInterval(loadPrinterStatus, 30000);

        // Load active job
        loadActiveJob();
    }
}

async function loadPrinterStatus() {
    try {
        const r = await fetch(API+'/student/printer-status', {headers:{'Authorization':`Bearer ${token}`}});
        const d = await r.json();
        const banner = document.getElementById('printerStatusBanner');
        if (!banner) return;
        banner.style.display = 'block';
        const online = d.isOnline ?? false;
        const name   = d.name || 'Printer';
        banner.innerHTML = `
          <div style="display:flex;align-items:center;gap:12px;padding:12px 16px;background:${online?'#f0fdf4':'#fef2f2'};border:1px solid ${online?'#86efac':'#fca5a5'};border-radius:12px">
            <div style="width:10px;height:10px;border-radius:50%;background:${online?'#10b981':'#ef4444'};box-shadow:0 0 6px ${online?'#10b981':'#ef4444'}88;flex-shrink:0"></div>
            <div>
              <div style="font-weight:600;font-size:13px;color:${online?'#065f46':'#991b1b'}">${name}</div>
              <div style="font-size:11px;color:#64748b">${online?'Online — ready to print':'Offline — contact admin'}</div>
            </div>
          </div>`;
    } catch {}
}

async function loadActiveJob() {
    try {
        const r = await fetch(API+'/student/jobs', {headers:{'Authorization':`Bearer ${token}`}});
        const jobs = await r.json();
        const active = jobs.find(j => j.status === 'pending' || j.status === 'printing');
        if (active) {
            _activeJobId = active._id;
            renderLiveJobCard(active);
            startJobPolling();
        }
    } catch {}
}

function renderLiveJobCard(job) {
    const card = document.getElementById('liveJobCard');
    if (!card) return;
    const colors = { pending:'#f59e0b', printing:'#4f46e5', completed:'#10b981', failed:'#ef4444' };
    const icons  = { pending:'⏳', printing:'🖨️', completed:'✅', failed:'❌' };
    const labels = { pending:'Waiting in queue…', printing:'Printing now…', completed:'Ready to collect!', failed:'Print failed' };
    const c = colors[job.status] || '#94a3b8';
    card.style.display = 'block';
    card.innerHTML = `
      <div style="background:white;border:1.5px solid ${c}44;border-radius:14px;overflow:hidden;box-shadow:0 4px 12px ${c}18">
        <div style="display:flex;align-items:center;gap:12px;padding:14px 16px">
          <div style="width:44px;height:44px;border-radius:50%;background:${c}18;display:flex;align-items:center;justify-content:center;font-size:20px;flex-shrink:0">${icons[job.status]||'📄'}</div>
          <div style="flex:1;min-width:0">
            <div style="font-weight:700;font-size:13px;color:${c}">${labels[job.status]||job.status}</div>
            <div style="font-size:12px;color:#64748b;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${job.fileName}</div>
            ${job.printerLocationName ? `<div style="font-size:11px;color:#94a3b8">🖨️ ${job.printerLocationName}</div>` : ''}
          </div>
          <div style="text-align:right;flex-shrink:0">
            <div style="font-size:12px;color:#64748b">${job.pages} pages</div>
            <div style="font-size:11px;padding:2px 8px;border-radius:10px;background:${c}18;color:${c};font-weight:700;margin-top:2px">${job.status.toUpperCase()}</div>
          </div>
        </div>
        ${(job.status==='pending'||job.status==='printing') ? `<div style="height:3px;background:${c}22"><div style="height:100%;background:${c};animation:progressPulse 1.5s infinite;width:${job.status==='printing'?'70%':'30%'}"></div></div>` : ''}
      </div>`;
}

function startJobPolling() {
    if (_jobPollInterval) clearInterval(_jobPollInterval);
    _jobPollInterval = setInterval(async () => {
        if (!_activeJobId) { clearInterval(_jobPollInterval); return; }
        try {
            const r = await fetch(`${API}/student/jobs/${_activeJobId}/status`, {headers:{'Authorization':`Bearer ${token}`}});
            const d = await r.json();
            renderLiveJobCard(d);
            if (d.status === 'completed' || d.status === 'failed') {
                clearInterval(_jobPollInterval);
                _activeJobId = null;
                if (d.status === 'completed') {
                    const wr = await fetch(API+'/student/wallet',{headers:{'Authorization':`Bearer ${token}`}});
                    const wd = await wr.json();
                    const el = document.getElementById('walletAmt');
                    if (el) el.textContent = wd.wallet ?? 0;
                }
            }
        } catch {}
    }, 4000);
}

async function showPrintHistory() {
    const panel = document.getElementById('historyPanel');
    const list  = document.getElementById('historyList');
    if (!panel || !list) return;
    panel.style.display = 'block';
    list.innerHTML = '<div style="color:#94a3b8;font-size:13px">Loading…</div>';
    panel.scrollIntoView({behavior:'smooth'});
    try {
        const r = await fetch(API+'/student/jobs', {headers:{'Authorization':`Bearer ${token}`}});
        const jobs = await r.json();
        if (!jobs.length) { list.innerHTML = '<div style="color:#94a3b8;font-size:13px">No print jobs yet.</div>'; return; }
        const statusColors = { pending:'#f59e0b', printing:'#4f46e5', completed:'#10b981', failed:'#ef4444' };
        list.innerHTML = jobs.map(j => {
            const c = statusColors[j.status] || '#94a3b8';
            const opts = [j.colorMode==='color'?'Color':'B&W', j.duplex?'Duplex':'', j.pagesPerSheet>1?`${j.pagesPerSheet}up`:'', j.pageRangeFrom>0?`p${j.pageRangeFrom}-${j.pageRangeTo}`:''].filter(Boolean).join(' · ');
            return `<div class="job-card" style="margin-bottom:10px">
              <div class="job-header">
                <div>
                  <div class="job-filename">📄 ${j.fileName}</div>
                  <div class="job-meta">${timeAgo(j.createdAt)}${j.printerLocationName?' · 🖨️ '+j.printerLocationName:''}</div>
                </div>
                <span class="badge" style="background:${c}18;color:${c};font-size:11px;padding:3px 10px;border-radius:10px;font-weight:700">${j.status.toUpperCase()}</span>
              </div>
              <div class="job-details">
                <span>📃 ${j.pages} pages</span>
                <span>₹${j.cost}</span>
                <span class="muted">${opts}</span>
              </div>
              ${j.status==='pending'||j.status==='printing' ? `<div style="height:3px;background:${c}22;border-radius:2px;margin-top:8px"><div style="height:100%;width:${j.status==='printing'?'70%':'25%'};background:${c};border-radius:2px"></div></div>` : ''}
            </div>`;
        }).join('');
    } catch { list.innerHTML = '<div style="color:#ef4444;font-size:13px">Failed to load history.</div>'; }
}

function showChangePasswordModal() {
    document.getElementById('cpCurrent').value = '';
    document.getElementById('cpNew').value = '';
    document.getElementById('cpConfirm').value = '';
    document.getElementById('changePassModal').classList.add('active');
    setTimeout(() => document.getElementById('cpCurrent').focus(), 100);
}

async function submitChangePassword() {
    const cur  = document.getElementById('cpCurrent').value;
    const nw   = document.getElementById('cpNew').value;
    const conf = document.getElementById('cpConfirm').value;
    if (!cur || !nw) { showAlert('Fill all fields','error'); return; }
    if (nw.length < 6) { showAlert('New password must be at least 6 characters','error'); return; }
    if (nw !== conf) { showAlert('Passwords do not match','error'); return; }
    try {
        const r = await fetch(API+'/auth/change-password', {
            method:'POST', headers:authHeaders(),
            body: JSON.stringify({ currentPassword:cur, newPassword:nw })
        });
        const d = await r.json();
        if (r.ok) {
            showAlert('Password changed successfully ✅','success');
            document.getElementById('changePassModal').classList.remove('active');
        } else { showAlert(d.error||'Failed','error'); }
    } catch { showAlert('Failed','error'); }
}

function selectFacultySection(id, name, el) {
    window._chosenSectionId = id;
    document.querySelectorAll('.section-select-item').forEach(item => {
        item.classList.remove('selected');
        item.querySelector('[id^="check-"]').style.display = 'none';
    });
    el.classList.add('selected');
    document.getElementById('check-'+id).style.display = 'block';
}

function selectChip(key, value, el) {
    window._printOpts[key] = value;
    el.closest('.chip-group').querySelectorAll('.chip').forEach(c => c.classList.remove('active'));
    el.classList.add('active');
}

function toggleRangeInputs() {
    const show = document.getElementById('rangeCheck').checked;
    document.getElementById('rangeInputs').style.display = show ? 'flex' : 'none';
}

async function submitPDF() {
    const input = document.getElementById('pdfInput');
    if (!input.files[0]) { showAlert('Please select a PDF file','error'); return; }
    const isFaculty = currentUser.role === 'faculty';
    if (isFaculty && !window._chosenSectionId) { showAlert('Please select a section to print for','error'); return; }
    const useRange = document.getElementById('rangeCheck')?.checked;
    const pageFrom = useRange ? (parseInt(document.getElementById('pageFrom')?.value)||0) : 0;
    const pageTo   = useRange ? (parseInt(document.getElementById('pageTo')?.value)||0)   : 0;
    if (useRange && (pageFrom <= 0 || pageTo < pageFrom)) { showAlert('Enter a valid page range','error'); return; }

    const fd = new FormData();
    fd.append('pdf',             input.files[0]);
    fd.append('colorMode',       window._printOpts.colorMode    || 'bw');
    fd.append('duplex',          document.getElementById('duplexCheck')?.checked || false);
    fd.append('pagesPerSheet',   window._printOpts.pagesPerSheet || '1');
    fd.append('pageFrom',        pageFrom);
    fd.append('pageTo',          pageTo);
    fd.append('chosenSectionId', window._chosenSectionId || '');

    const overlay = document.createElement('div');
    overlay.className = 'progress-overlay';
    overlay.innerHTML = `<div class="progress-box"><div class="progress-icon">🖨️</div><h3>Processing Print Job</h3><div class="progress-bar-wrap"><div class="progress-fill" id="pFill"></div></div><p id="pStatus">Uploading…</p></div>`;
    document.body.appendChild(overlay);

    let pct = 0;
    const ticker = setInterval(() => {
        if (pct < 85) { pct += 3; const f = document.getElementById('pFill'); if(f) f.style.width = pct+'%'; const s = document.getElementById('pStatus'); if(s) s.textContent = `Uploading… ${pct}%`; }
    }, 200);

    try {
        const r = await fetch(API+'/upload', { method:'POST', headers:{'Authorization':`Bearer ${token}`}, body:fd });
        const d = await r.json();
        clearInterval(ticker);
        const f = document.getElementById('pFill'); if(f) f.style.width='100%';
        const s = document.getElementById('pStatus'); if(s) s.textContent = r.ok ? '✅ Done!' : '❌ Failed';
        await new Promise(res => setTimeout(res, 700));
        overlay.remove();
        if (r.ok) {
            showAlert(`✅ Submitted! Pages: ${d.pages}, Cost: ₹${d.cost}${d.remainingWallet!=null?', Balance: ₹'+d.remainingWallet:''}`,'success');
            const wEl = document.getElementById('walletAmt'); if(wEl) wEl.textContent = d.remainingWallet ?? 0;
            input.value = '';
            document.getElementById('fileDropContent').innerHTML = `<div class="file-drop-icon">📁</div><div class="file-drop-text">Click to select PDF</div><div class="file-drop-sub">PDF only · Max 50 MB</div>`;
            // Start tracking the new job
            _activeJobId = d.jobId;
            if (_activeJobId) {
                await loadActiveJob();
            }
        } else { showAlert(d.error || 'Upload failed','error'); }
    } catch { clearInterval(ticker); overlay.remove(); showAlert('Upload failed','error'); }
}

// ============================================================
//  ADMIN DASHBOARD
// ============================================================
async function showAdminDashboard() {
    await loadSettings();
    await loadSections();

    document.getElementById('app').innerHTML = `
    <div class="dashboard">
      <nav class="topnav">
        <div class="topnav-left">
          <img src="/images/college_logo.png" alt="AGM" class="nav-college-logo">
          <div class="nav-title-group">
            <span class="nav-college-name">AGM Rural College</span>
            <span class="nav-logo">⚙️ PrintHub Admin</span>
          </div>
        </div>
        <div class="topnav-right">
          <span class="nav-user">👤 ${currentUser.name}</span>
          <button class="btn btn-sm" onclick="showChangePasswordModal()" style="margin-right:6px">🔐 Password</button>
          <button class="btn-logout" onclick="logout()">Logout</button>
        </div>
      </nav>

      <div class="admin-tabs">
        <button class="tab-btn active" onclick="switchTab('stats',this)">📊 Stats</button>
        <button class="tab-btn"        onclick="switchTab('students',this)">👥 Students</button>
        <button class="tab-btn"        onclick="switchTab('jobs',this)">🖨️ Jobs</button>
        <button class="tab-btn"        onclick="switchTab('queue',this)">📋 Queue</button>
        <button class="tab-btn"        onclick="switchTab('faculty',this)">🎓 Faculty</button>
        <button class="tab-btn"        onclick="switchTab('printers',this)">🖨️ Printers</button>
        <button class="tab-btn"        onclick="switchTab('sections',this)">🗂️ Sections</button>
        <button class="tab-btn"        onclick="switchTab('settings',this)">⚙️ Settings</button>
      </div>

      <div class="page-content">
        <div id="alertContainer"></div>

        <!-- ── STATS TAB ── -->
        <div id="tab-stats" class="tab-panel">
          <div class="panel-header"><h2>📊 Dashboard Stats</h2><button class="btn btn-sm" onclick="loadStats()">↻ Refresh</button></div>
          <div id="statsContent"><div class="empty-state">Loading…</div></div>
        </div>

        <!-- ── STUDENTS TAB ── -->
        <div id="tab-students" class="tab-panel" style="display:none">
          <div class="panel-header">
            <h2>👥 Students</h2>
            <span id="studentCount" class="count-badge">0</span>
            <div style="margin-left:auto">
              <button class="btn btn-primary btn-sm" onclick="showAddStudentModal()">+ Add Student</button>
            </div>
          </div>
          <div class="search-bar-wrap">
            <input type="text" id="studentSearch" placeholder="🔍 Search by name, email or section…" oninput="filterStudents()">
          </div>
          <div id="sectionFilterChips" class="chip-group filter-chips"></div>
          <div id="studentsList"></div>
        </div>

        <!-- ── PRINT JOBS TAB ── -->
        <div id="tab-jobs" class="tab-panel" style="display:none">
          <div class="panel-header">
            <h2>🖨️ Print Jobs</h2>
            <button class="btn btn-sm" onclick="loadPrintJobs()">↻ Refresh</button>
          </div>
          <div class="search-bar-wrap">
            <input type="text" id="jobSearch" placeholder="🔍 Search by file name or student…" oninput="filterJobs()">
          </div>
          <div id="jobsList"></div>
        </div>

        <!-- ── PRINTER QUEUE TAB ── -->
        <div id="tab-queue" class="tab-panel" style="display:none">
          <div class="panel-header"><h2>📋 Printer Queue</h2><button class="btn btn-sm" onclick="loadPrinterQueue()">↻ Refresh</button></div>
          <div id="queueContent"><div class="empty-state">Loading…</div></div>
        </div>

        <!-- ── SECTIONS TAB ── -->
        <div id="tab-sections" class="tab-panel" style="display:none">
          <div class="panel-header">
            <h2>🗂️ Sections</h2>
            <button class="btn btn-primary btn-sm" onclick="showCreateSection()">+ New Section</button>
          </div>
          <div id="sectionsList"></div>
        </div>

        <!-- ── FACULTY TAB ── -->
        <div id="tab-faculty" class="tab-panel" style="display:none">
          <div class="panel-header">
            <h2>🎓 Faculty</h2>
            <button class="btn btn-primary btn-sm" onclick="showAddFacultyModal()">+ Add Faculty</button>
          </div>
          <div id="facultyList"></div>
        </div>

        <!-- ── PRINTERS TAB ── -->
        <div id="tab-printers" class="tab-panel" style="display:none">
          <div class="panel-header">
            <h2>🖨️ Printer Locations</h2>
            <button class="btn btn-primary btn-sm" onclick="showAddPrinterModal()">+ Add Printer</button>
          </div>
          <p style="color:#64748b;font-size:13px;margin-bottom:16px">Each printer has a unique Agent Key. Copy it to <code>print-agent/.env</code>.</p>
          <div id="printersList"></div>
        </div>

        <!-- ── SETTINGS TAB ── -->
        <div id="tab-settings" class="tab-panel" style="display:none">
          <h2>⚙️ System Settings</h2>
          <div class="settings-grid">
            <div class="settings-card">
              <h3>💰 Pricing</h3>
              <div class="form-group"><label>Price per page (₹)</label><input type="number" id="priceInput" min="0.5" step="0.5" value="${settings.pricePerPage}"></div>
              <div class="form-group"><label>Max pages per job (0 = unlimited)</label><input type="number" id="maxPagesInput" min="0" value="${settings.maxPagesPerJob||0}"></div>
            </div>
            <div class="settings-card">
              <h3>🔒 Student Permissions</h3>
              ${permToggle('allowColor',       'Allow Color Printing',           settings.allowColor)}
              ${permToggle('allowDuplex',      'Allow Duplex Printing',          settings.allowDuplex)}
              ${permToggle('allowPageRange',   'Allow Custom Page Range',        settings.allowPageRange)}
              ${permToggle('allowPagesPerSheet','Allow Multiple Pages per Sheet',settings.allowPagesPerSheet)}
            </div>
          </div>
          <button class="btn btn-primary" onclick="saveSettings()">💾 Save Settings</button>
        </div>
      </div>
    </div>

    <!-- Add Funds Modal -->
    <div id="fundsModal" class="modal">
      <div class="modal-box">
        <div class="modal-header"><h3>Add Wallet Funds</h3><button class="modal-close" onclick="closeFundsModal()">✕</button></div>
        <p id="fundsStudentName" class="modal-sub"></p>
        <div class="form-group"><label>Amount (₹)</label><input type="number" id="fundsAmount" min="1" placeholder="Enter amount"></div>
        <button class="btn btn-primary" onclick="addFunds()">Add Funds</button>
      </div>
    </div>

    <!-- Create Section Modal -->
    <div id="sectionModal" class="modal">
      <div class="modal-box">
        <div class="modal-header"><h3>Create Section</h3><button class="modal-close" onclick="closeSectionModal()">✕</button></div>
        <p class="modal-sub">e.g. CSE, ECE, MECH, MBA</p>
        <div class="form-group"><label>Section Name</label><input type="text" id="sectionNameInput" placeholder="e.g. CSE" style="text-transform:uppercase"></div>
        <button class="btn btn-primary" onclick="createSection()">Create</button>
      </div>
    </div>

    <!-- Add Student Modal -->
    <div id="addStudentModal" class="modal">
      <div class="modal-box">
        <div class="modal-header"><h3>Add Student</h3><button class="modal-close" onclick="closeAddStudentModal()">✕</button></div>
        <p class="modal-sub">Create a student account and assign to a section</p>
        <div class="form-group"><label>Full Name *</label><input type="text" id="addStudentName" placeholder="Student full name"></div>
        <div class="form-group"><label>Email *</label><input type="email" id="addStudentEmail" placeholder="student@email.com"></div>
        <div class="form-group"><label>Password *</label><input type="password" id="addStudentPass" placeholder="Set a password" value="student123"></div>
        <div class="form-group"><label>Section</label><select id="addStudentSection"><option value="">— No section —</option></select></div>
        <div class="form-group"><label>Initial Wallet (₹)</label><input type="number" id="addStudentWallet" placeholder="0" min="0" value="0"></div>
        <button class="btn btn-primary" onclick="createStudent()">Add Student</button>
      </div>
    </div>

    <!-- Add Faculty Modal -->
    <div id="addFacultyModal" class="modal">
      <div class="modal-box">
        <div class="modal-header"><h3>Add Faculty</h3><button class="modal-close" onclick="document.getElementById('addFacultyModal').classList.remove('active')">✕</button></div>
        <p class="modal-sub" style="color:#10b981;font-weight:600">Faculty get free unlimited printing</p>
        <div class="form-group"><label>Full Name *</label><input type="text" id="addFacultyName" placeholder="Dr. / Prof. name"></div>
        <div class="form-group"><label>Email *</label><input type="email" id="addFacultyEmail" placeholder="faculty@college.com"></div>
        <div class="form-group"><label>Password *</label><input type="password" id="addFacultyPass" value="faculty123"></div>
        <div class="form-group"><label>Department</label><input type="text" id="addFacultyDept" placeholder="e.g. CSE, ECE"></div>
        <div class="form-group"><label>Assign Printer</label><select id="addFacultyPrinter"><option value="">— Select printer —</option></select></div>
        <div class="form-group"><label>Assign Section</label><select id="addFacultySection"><option value="">— No section —</option></select></div>
        <button class="btn btn-primary" onclick="createFaculty()">Add Faculty</button>
      </div>
    </div>

    <!-- Add Printer Modal -->
    <div id="addPrinterModal" class="modal">
      <div class="modal-box">
        <div class="modal-header"><h3>Add Printer Location</h3><button class="modal-close" onclick="document.getElementById('addPrinterModal').classList.remove('active')">✕</button></div>
        <p class="modal-sub">e.g. HOD Room, Lab 1, Library</p>
        <div class="form-group"><label>Printer Name *</label><input type="text" id="addPrinterName" placeholder="e.g. HOD Room Printer"></div>
        <div class="form-group"><label>Description</label><input type="text" id="addPrinterDesc" placeholder="e.g. Ground floor, near reception"></div>
        <button class="btn btn-primary" onclick="createPrinter()">Add Printer</button>
      </div>
    </div>

    <!-- Assign Printer Modal -->
    <div id="assignPrinterModal" class="modal">
      <div class="modal-box">
        <div class="modal-header"><h3 id="assignPrinterTitle">Assign Printer</h3><button class="modal-close" onclick="document.getElementById('assignPrinterModal').classList.remove('active')">✕</button></div>
        <p id="assignPrinterSub" class="modal-sub"></p>
        <div class="form-group"><label>Select Printer</label><select id="assignPrinterSelect"><option value="">— No printer assigned (use default) —</option></select></div>
        <button class="btn btn-primary" onclick="doAssignPrinter()">Assign</button>
      </div>
    </div>

    <!-- Change Password Modal (admin) -->
    <div id="changePassModal" class="modal">
      <div class="modal-box">
        <div class="modal-header"><h3>🔐 Change Password</h3><button class="modal-close" onclick="document.getElementById('changePassModal').classList.remove('active')">✕</button></div>
        <div class="form-group"><label>Current Password</label><div class="input-icon-wrap"><input type="password" id="cpCurrent" placeholder="Enter current password"><span class="toggle-pass" onclick="togglePass('cpCurrent',this)">👁</span></div></div>
        <div class="form-group"><label>New Password</label><div class="input-icon-wrap"><input type="password" id="cpNew" placeholder="Min 6 characters"><span class="toggle-pass" onclick="togglePass('cpNew',this)">👁</span></div></div>
        <div class="form-group"><label>Confirm New Password</label><input type="password" id="cpConfirm" placeholder="Repeat new password"></div>
        <button class="btn btn-primary" onclick="submitChangePassword()">Update Password</button>
      </div>
    </div>`;

    await loadStudents();
    await loadPrintJobs();
    renderSections();
    loadStats();
}

// ── Stats ─────────────────────────────────────────────────────
async function loadStats() {
    try {
        const r = await fetch(API+'/admin/stats', {headers:{'Authorization':`Bearer ${token}`}});
        const d = await r.json();
        const el = document.getElementById('statsContent');
        if (!el) return;
        el.innerHTML = `
          <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:12px;margin-bottom:20px">
            ${statCard('📅 Jobs Today',    d.jobsToday,    '#4f46e5')}
            ${statCard('💰 Revenue Today','₹'+(d.todayRevenue||0).toFixed(0), '#10b981')}
            ${statCard('📄 Pages Today',  d.todayPages,   '#06b6d4')}
            ${statCard('⏳ In Queue',      (d.pendingJobs||0)+(d.printingJobs||0), '#f59e0b')}
          </div>
          <h3 style="font-size:14px;font-weight:700;color:#1e293b;margin-bottom:10px">All Time</h3>
          <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:12px;margin-bottom:20px">
            ${statCard('👥 Students',     d.totalStudents, '#7c3aed')}
            ${statCard('🎓 Faculty',      d.totalFaculty,  '#7c3aed')}
            ${statCard('🖨️ Total Jobs',   d.totalJobs,     '#4f46e5')}
            ${statCard('💰 Total Revenue','₹'+(d.totalRevenue||0).toFixed(0), '#10b981')}
            ${statCard('📄 Pages Printed',d.totalPages,    '#06b6d4')}
            ${statCard('✅ Completed',    d.completedJobs, '#10b981')}
            ${statCard('❌ Failed',       d.failedJobs,    '#ef4444')}
          </div>
          ${d.printers?.length ? `
          <h3 style="font-size:14px;font-weight:700;color:#1e293b;margin-bottom:10px">Printer Status</h3>
          <div style="display:flex;flex-direction:column;gap:8px">
            ${d.printers.map(p=>`
              <div style="display:flex;align-items:center;gap:12px;padding:12px 16px;background:white;border:1px solid #e2e8f0;border-radius:12px">
                <div style="width:10px;height:10px;border-radius:50%;background:${p.isOnline?'#10b981':'#ef4444'};box-shadow:0 0 6px ${p.isOnline?'#10b981':'#ef4444'}88;flex-shrink:0"></div>
                <span style="font-weight:600;font-size:13px;flex:1">${p.name}</span>
                <span style="font-size:12px;font-weight:600;color:${p.isOnline?'#10b981':'#ef4444'}">${p.isOnline?'Online':'Offline'}</span>
              </div>`).join('')}
          </div>` : ''}`;
    } catch { const el = document.getElementById('statsContent'); if(el) el.innerHTML = '<div class="empty-state">Failed to load stats</div>'; }
}

function statCard(label, value, color) {
    return `<div style="background:white;border:1px solid #e2e8f0;border-radius:14px;padding:16px;box-shadow:0 2px 6px #0000000a">
      <div style="font-size:22px;font-weight:800;color:${color}">${value}</div>
      <div style="font-size:12px;color:#64748b;font-weight:500;margin-top:2px">${label}</div>
    </div>`;
}

// ── Printer Queue ─────────────────────────────────────────────
async function loadPrinterQueue() {
    try {
        const r = await fetch(API+'/admin/printer-queue', {headers:{'Authorization':`Bearer ${token}`}});
        const queue = await r.json();
        const el = document.getElementById('queueContent');
        if (!el) return;
        if (!queue.length) { el.innerHTML = '<div class="empty-state">No printers configured</div>'; return; }
        el.innerHTML = queue.map(printer => {
            const isOnline = printer.isOnline;
            const jobs = printer.jobs || [];
            return `<div style="background:white;border:1.5px solid ${isOnline?'#86efac':'#e2e8f0'};border-radius:16px;margin-bottom:16px;overflow:hidden">
              <div style="display:flex;align-items:center;gap:10px;padding:14px 16px;background:${isOnline?'#f0fdf4':'#f8fafc'}">
                <div style="width:10px;height:10px;border-radius:50%;background:${isOnline?'#10b981':'#ef4444'};box-shadow:0 0 6px ${isOnline?'#10b981':'#ef4444'}88;flex-shrink:0"></div>
                <span style="font-weight:700;font-size:15px;flex:1">${printer.printerName}</span>
                ${printer.printing>0?`<span style="font-size:11px;padding:3px 10px;border-radius:10px;background:#eef2ff;color:#4f46e5;font-weight:700">Printing ${printer.printing}</span>`:''}
                ${printer.pending>0?`<span style="font-size:11px;padding:3px 10px;border-radius:10px;background:#fffbeb;color:#d97706;font-weight:700">${printer.pending} waiting</span>`:''}
                ${!printer.printing&&!printer.pending?`<span style="font-size:11px;color:#94a3b8">Empty queue</span>`:''}
              </div>
              ${jobs.length ? jobs.map((j,i) => {
                const c = j.status==='printing'?'#4f46e5':'#f59e0b';
                return `<div style="display:flex;align-items:center;gap:12px;padding:10px 16px;border-top:1px solid #f1f5f9">
                  <div style="width:28px;height:28px;border-radius:50%;background:${c}18;display:flex;align-items:center;justify-content:center;font-size:13px;font-weight:700;color:${c};flex-shrink:0">
                    ${j.status==='printing'?'🖨️':(i+1)}
                  </div>
                  <div style="flex:1;min-width:0">
                    <div style="font-weight:600;font-size:13px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${j.fileName}</div>
                    <div style="font-size:11px;color:#64748b">${j.userName||''}${j.userSection?' · '+j.userSection:''}</div>
                  </div>
                  <div style="text-align:right;flex-shrink:0">
                    <div style="font-size:12px;color:#64748b">${j.pages} pages</div>
                    <span style="font-size:10px;padding:2px 8px;border-radius:8px;background:${c}18;color:${c};font-weight:700">${j.status==='printing'?'Printing':'Waiting'}</span>
                  </div>
                </div>`;
              }).join('') : '<div style="padding:14px 16px;color:#94a3b8;font-size:13px">No active jobs</div>'}
            </div>`;
        }).join('');
    } catch { const el = document.getElementById('queueContent'); if(el) el.innerHTML = '<div class="empty-state">Failed to load queue</div>'; }
}

function permToggle(id, label, checked) {
    return `<div class="perm-row"><span>${label}</span><label class="toggle-switch"><input type="checkbox" id="perm-${id}" ${checked?'checked':''}><span class="toggle-slider"></span></label></div>`;
}

function switchTab(name, btn) {
    document.querySelectorAll('.tab-panel').forEach(p => p.style.display='none');
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
    document.getElementById('tab-'+name).style.display = 'block';
    btn.classList.add('active');
    if (name === 'queue') loadPrinterQueue();
    if (name === 'stats') loadStats();
}

// ── Students ──────────────────────────────────────────────────
let _activeSection = 'All';

async function loadStudents() {
    try {
        const r = await fetch(API+'/admin/students',{headers:{'Authorization':`Bearer ${token}`}});
        allStudents = await r.json();
        buildSectionChips();
        renderStudents();
        const el = document.getElementById('studentCount'); if(el) el.textContent = allStudents.length;
    } catch { showAlert('Failed to load students','error'); }
}

function buildSectionChips() {
    const sections = ['All', ...new Set(allStudents.map(s=>s.section).filter(Boolean)).values()].sort((a,b)=>a==='All'?-1:a.localeCompare(b));
    const wrap = document.getElementById('sectionFilterChips');
    if (!wrap) return;
    wrap.innerHTML = sections.map(sec => {
        const count = sec==='All' ? allStudents.length : allStudents.filter(s=>s.section===sec).length;
        return `<button class="chip filter-chip ${sec===_activeSection?'active':''}" onclick="setSectionFilter('${sec}',this)">${sec} (${count})</button>`;
    }).join('');
}

function setSectionFilter(sec, el) {
    _activeSection = sec;
    document.querySelectorAll('.filter-chip').forEach(c=>c.classList.remove('active'));
    el.classList.add('active');
    renderStudents();
}

function filterStudents() { renderStudents(); }

function renderStudents() {
    const q    = (document.getElementById('studentSearch')?.value||'').toLowerCase();
    const list = allStudents.filter(s => {
        const matchSec = _activeSection==='All' || s.section===_activeSection;
        const matchQ   = !q || s.name.toLowerCase().includes(q) || s.email.toLowerCase().includes(q) || (s.section||'').toLowerCase().includes(q);
        return matchSec && matchQ;
    });
    const el = document.getElementById('studentsList');
    if (!el) return;
    if (!list.length) { el.innerHTML = `<div class="empty-state">No students found</div>`; return; }
    el.innerHTML = `<table class="data-table">
      <thead><tr><th>Name</th><th>Section</th><th>Email</th><th>Wallet</th><th>Actions</th></tr></thead>
      <tbody>${list.map(s=>`
        <tr>
          <td><div class="student-name-cell"><div class="avatar" style="background:${sectionColor(s.section)}">${s.name[0]?.toUpperCase()||'?'}</div><strong>${s.name}</strong></div></td>
          <td>${s.section ? `<span class="sec-tag" style="background:${sectionColor(s.section)}20;color:${sectionColor(s.section)}">${s.section}</span>` : '—'}</td>
          <td class="muted">${s.email}</td>
          <td class="wallet-val">₹${s.wallet||0}</td>
          <td style="display:flex;gap:6px;flex-wrap:wrap">
            <button class="btn btn-sm btn-green" onclick="openFundsModal('${s._id}','${s.name}')">+ Funds</button>
            <button class="btn btn-sm btn-red" onclick="deleteUser('${s._id}','${s.name}','student')">🗑️ Delete</button>
          </td>
        </tr>`).join('')}
      </tbody></table>`;
}

const SECTION_COLORS = ['#6366f1','#06b6d4','#10b981','#f59e0b','#ef4444','#8b5cf6','#ec4899'];
function sectionColor(sec) {
    if (!sec) return '#94a3b8';
    return SECTION_COLORS[sec.charCodeAt(0) % SECTION_COLORS.length];
}

// ── Delete user ───────────────────────────────────────────────
async function deleteUser(id, name, role) {
    if (!confirm(`Delete ${role} "${name}"? This cannot be undone.`)) return;
    try {
        const r = await fetch(`${API}/admin/users/${id}`, {method:'DELETE', headers:authHeaders()});
        const d = await r.json();
        if (r.ok) {
            showAlert(`"${name}" deleted`,'success');
            if (role === 'student') loadStudents();
            else loadFaculty();
        } else { showAlert(d.error||'Failed','error'); }
    } catch { showAlert('Failed','error'); }
}

// ── Funds modal ───────────────────────────────────────────────
let _fundsStudentId = null;
function openFundsModal(id, name) {
    _fundsStudentId = id;
    document.getElementById('fundsStudentName').textContent = name;
    document.getElementById('fundsAmount').value = '';
    document.getElementById('fundsModal').classList.add('active');
    setTimeout(()=>document.getElementById('fundsAmount').focus(),100);
}
function closeFundsModal() { document.getElementById('fundsModal').classList.remove('active'); }

async function addFunds() {
    const amount = parseInt(document.getElementById('fundsAmount').value);
    if (!amount || amount <= 0) { showAlert('Enter a valid amount','error'); return; }
    try {
        const r = await fetch(API+'/admin/add-wallet',{method:'POST',headers:authHeaders(),body:JSON.stringify({studentId:_fundsStudentId,amount})});
        const d = await r.json();
        if (r.ok) { showAlert(`Added ₹${amount} successfully`,'success'); closeFundsModal(); loadStudents(); }
        else { showAlert(d.error||'Failed','error'); }
    } catch { showAlert('Failed to add funds','error'); }
}

// ── Add Student modal ─────────────────────────────────────────
function showAddStudentModal() {
    const sel = document.getElementById('addStudentSection');
    sel.innerHTML = '<option value="">— No section —</option>';
    allSections.forEach(s => sel.innerHTML += `<option value="${s.name}">${s.name}</option>`);
    document.getElementById('addStudentName').value   = '';
    document.getElementById('addStudentEmail').value  = '';
    document.getElementById('addStudentPass').value   = 'student123';
    document.getElementById('addStudentWallet').value = '0';
    document.getElementById('addStudentModal').classList.add('active');
    setTimeout(() => document.getElementById('addStudentName').focus(), 100);
}
function closeAddStudentModal() { document.getElementById('addStudentModal').classList.remove('active'); }

async function createStudent() {
    const name    = document.getElementById('addStudentName').value.trim();
    const email   = document.getElementById('addStudentEmail').value.trim();
    const password= document.getElementById('addStudentPass').value;
    const section = document.getElementById('addStudentSection').value;
    const wallet  = parseInt(document.getElementById('addStudentWallet').value) || 0;
    if (!name || !email || !password || password.length < 6) { showAlert('Fill all required fields (password min 6 chars)','error'); return; }
    try {
        const r = await fetch(API+'/admin/students', {method:'POST', headers:authHeaders(), body:JSON.stringify({name,email,password,section,wallet})});
        const d = await r.json();
        if (r.ok) { showAlert(`Student "${name}" added`,'success'); closeAddStudentModal(); loadStudents(); }
        else { showAlert(d.error||'Failed','error'); }
    } catch { showAlert('Failed','error'); }
}

// ── Print Jobs ────────────────────────────────────────────────
let allJobs = [];

async function loadPrintJobs() {
    try {
        const r = await fetch(API+'/admin/print-jobs',{headers:{'Authorization':`Bearer ${token}`}});
        allJobs = await r.json();
        renderJobs();
    } catch { showAlert('Failed to load jobs','error'); }
}

function filterJobs() { renderJobs(); }

function renderJobs() {
    const q = (document.getElementById('jobSearch')?.value||'').toLowerCase();
    const list = allJobs.filter(j => !q || (j.fileName||'').toLowerCase().includes(q) || (j.userName||j.studentName||'').toLowerCase().includes(q));
    const el = document.getElementById('jobsList');
    if (!el) return;
    if (!list.length) { el.innerHTML = `<div class="empty-state">No print jobs yet</div>`; return; }
    el.innerHTML = list.map(j => {
        const statusCls = { pending:'badge-warn', printing:'badge-info', completed:'badge-ok', failed:'badge-err' }[j.status] || 'badge-warn';
        const name = j.userName || j.studentName || '';
        const section = j.userSection || j.studentSection || '';
        const opts = [j.colorMode==='color'?'🎨 Color':'⬛ B&W', j.duplex?'🔄 Duplex':'📄 Simplex', j.pagesPerSheet>1?`${j.pagesPerSheet}up`:'', j.pageRangeFrom>0?`p${j.pageRangeFrom}-${j.pageRangeTo}`:''].filter(Boolean).join(' · ');
        return `<div class="job-card">
          <div class="job-header">
            <div>
              <div class="job-filename">📄 ${j.fileName}</div>
              <div class="job-meta">${name}${section?' · '+section:''} · ${new Date(j.createdAt).toLocaleString()}${j.printerLocationName?' · 🖨️ '+j.printerLocationName:''}</div>
            </div>
            <span class="badge ${statusCls}">${j.status.toUpperCase()}</span>
          </div>
          <div class="job-details">
            <span>📃 ${j.pages} pages</span><span>₹${j.cost}</span><span class="muted">${opts}</span>
          </div>
        </div>`;
    }).join('');
}

// ── Sections ──────────────────────────────────────────────────
async function loadSections() {
    try { const r = await fetch(API+'/sections'); allSections = await r.json(); }
    catch { allSections = []; }
}

function renderSections() {
    const el = document.getElementById('sectionsList');
    if (!el) return;
    if (!allSections.length) { el.innerHTML = `<div class="empty-state">No sections yet. Create one!</div>`; return; }
    el.innerHTML = `<div class="sections-grid">${allSections.map(s => {
        const printer = allPrinters.find(p => p._id === s.assignedPrinterId);
        return `<div class="section-card">
          <div class="section-icon" style="background:${sectionColor(s.name)}20;color:${sectionColor(s.name)}">🗂️</div>
          <div class="section-name">${s.name}</div>
          ${printer ? `<div class="section-printer ${printer.isOnline?'printer-online':'printer-offline'}"><span class="status-dot-sm"></span> 🖨️ ${printer.name}</div>` : `<div class="section-printer printer-none">⚠️ No printer</div>`}
          <div class="section-count">${allStudents.filter(st=>st.section===s.name).length} students</div>
          <div style="display:flex;gap:6px;margin-top:8px">
            <button class="btn btn-sm btn-primary" style="flex:1" onclick="showAssignSectionPrinter('${s._id}','${s.name}','${s.assignedPrinterId||''}')">
              ${printer ? '🔄 Change Printer' : '🖨️ Assign Printer'}
            </button>
            <button class="btn btn-sm btn-red" onclick="deleteSection('${s._id}','${s.name}')">🗑️</button>
          </div>
        </div>`;
    }).join('')}</div>`;
}

function showCreateSection() { document.getElementById('sectionNameInput').value=''; document.getElementById('sectionModal').classList.add('active'); setTimeout(()=>document.getElementById('sectionNameInput').focus(),100); }
function closeSectionModal() { document.getElementById('sectionModal').classList.remove('active'); }

function showAssignSectionPrinter(sectionId, sectionName, currentPrinterId) {
    _assignType = 'section'; _assignPrinterId = ''; window._assignSectionId = sectionId;
    document.getElementById('assignPrinterTitle').textContent = `Assign Printer — ${sectionName}`;
    document.getElementById('assignPrinterSub').textContent = 'All students in this section will print to this printer.';
    const sel = document.getElementById('assignPrinterSelect');
    sel.innerHTML = '<option value="">— Remove printer assignment —</option>';
    allPrinters.forEach(p => sel.innerHTML += `<option value="${p._id}" ${p._id===currentPrinterId?'selected':''}>🖨️ ${p.name}${p.isOnline?' ✅':' (offline)'}</option>`);
    document.getElementById('assignPrinterModal').classList.add('active');
}

const _origDoAssignPrinter = window.doAssignPrinter;
window.doAssignPrinter = async function() {
    if (window._assignSectionId) {
        const printerId = document.getElementById('assignPrinterSelect').value;
        try {
            const r = await fetch(`${API}/admin/sections/${window._assignSectionId}/assign-printer`, {method:'POST',headers:authHeaders(),body:JSON.stringify({printerId})});
            const d = await r.json();
            if (r.ok) { showAlert(printerId?'Printer assigned ✅':'Assignment removed','success'); document.getElementById('assignPrinterModal').classList.remove('active'); window._assignSectionId=null; await loadSections(); renderSections(); }
            else { showAlert(d.error||'Failed','error'); }
        } catch { showAlert('Failed','error'); }
    } else { await _origDoAssignPrinter(); }
};

async function createSection() {
    const name = document.getElementById('sectionNameInput').value.trim().toUpperCase();
    if (!name) { showAlert('Enter a section name','error'); return; }
    try {
        const r = await fetch(API+'/admin/sections',{method:'POST',headers:authHeaders(),body:JSON.stringify({name})});
        const d = await r.json();
        if (r.ok) { showAlert(`Section "${name}" created`,'success'); closeSectionModal(); await loadSections(); renderSections(); buildSectionChips(); }
        else { showAlert(d.error||'Failed','error'); }
    } catch { showAlert('Failed','error'); }
}

async function deleteSection(id, name) {
    if (!confirm(`Delete section "${name}"? Students won't be affected.`)) return;
    try {
        const r = await fetch(API+'/admin/sections/'+id,{method:'DELETE',headers:authHeaders()});
        if (r.ok) { showAlert(`"${name}" deleted`,'success'); await loadSections(); renderSections(); buildSectionChips(); }
        else { showAlert('Failed','error'); }
    } catch { showAlert('Failed','error'); }
}

// ── Settings ──────────────────────────────────────────────────
async function loadSettings() {
    try { const r = await fetch(API+'/settings'); settings = await r.json(); } catch {}
}

async function saveSettings() {
    const price = parseFloat(document.getElementById('priceInput')?.value);
    if (!price || price <= 0) { showAlert('Enter a valid price','error'); return; }
    const body = {
        pricePerPage:       price,
        maxPagesPerJob:     parseInt(document.getElementById('maxPagesInput')?.value)||0,
        allowColor:         document.getElementById('perm-allowColor')?.checked ?? true,
        allowDuplex:        document.getElementById('perm-allowDuplex')?.checked ?? true,
        allowPageRange:     document.getElementById('perm-allowPageRange')?.checked ?? true,
        allowPagesPerSheet: document.getElementById('perm-allowPagesPerSheet')?.checked ?? true,
    };
    try {
        const r = await fetch(API+'/admin/settings',{method:'POST',headers:authHeaders(),body:JSON.stringify(body)});
        const d = await r.json();
        if (r.ok) { settings = d.settings; showAlert('Settings saved ✅','success'); }
        else { showAlert(d.error||'Failed','error'); }
    } catch { showAlert('Failed','error'); }
}

// ── Printers ──────────────────────────────────────────────────
let allPrinters = [];

async function loadPrinters() {
    try {
        const r = await fetch(API+'/admin/printer-locations', {headers:{'Authorization':`Bearer ${token}`}});
        allPrinters = await r.json();
        renderPrinters();
    } catch { showAlert('Failed to load printers','error'); }
}

function renderPrinters() {
    const el = document.getElementById('printersList');
    if (!el) return;
    if (!allPrinters.length) { el.innerHTML = `<div class="empty-state">No printers yet.</div>`; return; }
    el.innerHTML = allPrinters.map(p => `
      <div class="printer-card">
        <div class="printer-header">
          <div class="printer-status ${p.isOnline?'online':'offline'}"><span class="status-dot"></span>${p.isOnline?'Online':'Offline'}</div>
          <button class="btn btn-sm btn-red" onclick="deletePrinter('${p._id}','${p.name}')">Delete</button>
        </div>
        <div class="printer-name">🖨️ ${p.name}</div>
        ${p.description?`<div class="printer-desc">${p.description}</div>`:''}
        ${p.lastSeen?`<div class="printer-lastseen">Last seen: ${new Date(p.lastSeen).toLocaleString()}</div>`:''}
        <div class="printer-key-wrap">
          <label>Agent Key</label>
          <div class="printer-key-row">
            <code class="printer-key" id="key-${p._id}">${p.agentKey}</code>
            <button class="btn btn-sm" onclick="copyKey('${p._id}')">📋 Copy</button>
          </div>
        </div>
        <div style="margin-top:12px;display:flex;gap:8px;flex-wrap:wrap">
          <button class="btn btn-sm" onclick="openAssignModal('section','${p._id}','${p.name}')">Assign to Section</button>
          <button class="btn btn-sm" onclick="openAssignModal('faculty','${p._id}','${p.name}')">Assign to Faculty</button>
        </div>
      </div>`).join('');
}

function copyKey(printerId) {
    const key = document.getElementById('key-'+printerId)?.textContent;
    if (key) navigator.clipboard.writeText(key).then(() => showAlert('Agent key copied!','success'));
}

function showAddPrinterModal() {
    document.getElementById('addPrinterName').value = '';
    document.getElementById('addPrinterDesc').value = '';
    document.getElementById('addPrinterModal').classList.add('active');
    setTimeout(() => document.getElementById('addPrinterName').focus(), 100);
}

async function createPrinter() {
    const name = document.getElementById('addPrinterName').value.trim();
    const desc = document.getElementById('addPrinterDesc').value.trim();
    if (!name) { showAlert('Printer name required','error'); return; }
    try {
        const r = await fetch(API+'/admin/printer-locations', {method:'POST',headers:authHeaders(),body:JSON.stringify({name,description:desc})});
        const d = await r.json();
        if (r.ok) { showAlert(`Printer "${name}" added`,'success'); document.getElementById('addPrinterModal').classList.remove('active'); await loadPrinters(); }
        else { showAlert(d.error||'Failed','error'); }
    } catch { showAlert('Failed','error'); }
}

async function deletePrinter(id, name) {
    if (!confirm(`Delete printer "${name}"?`)) return;
    try {
        const r = await fetch(API+'/admin/printer-locations/'+id, {method:'DELETE',headers:authHeaders()});
        if (r.ok) { showAlert(`"${name}" deleted`,'success'); await loadPrinters(); }
        else { showAlert('Failed','error'); }
    } catch { showAlert('Failed','error'); }
}

// ── Assign printer modal ──────────────────────────────────────
let _assignType = '';
let _assignPrinterId = '';

function openAssignModal(type, printerId, printerName) {
    _assignType = type; _assignPrinterId = printerId;
    document.getElementById('assignPrinterTitle').textContent = `Assign "${printerName}" to ${type==='section'?'Section':'Faculty'}`;
    const sel = document.getElementById('assignPrinterSelect');
    sel.innerHTML = '<option value="">— Remove assignment —</option>';
    if (type === 'section') {
        document.getElementById('assignPrinterSub').textContent = 'All students in this section will print to this printer.';
        allSections.forEach(s => sel.innerHTML += `<option value="${s._id}">${s.name}</option>`);
    } else {
        document.getElementById('assignPrinterSub').textContent = 'This faculty will print to the selected printer.';
        allFaculty.forEach(u => sel.innerHTML += `<option value="${u._id}">${u.name}${u.department?' ('+u.department+')':''}</option>`);
    }
    document.getElementById('assignPrinterModal').classList.add('active');
}

async function doAssignPrinter() {
    const targetId = document.getElementById('assignPrinterSelect').value;
    if (!targetId) { showAlert('Select a target','error'); return; }
    try {
        const url = _assignType==='section' ? `${API}/admin/sections/${targetId}/assign-printer` : `${API}/admin/users/${targetId}/assign-printer`;
        const r = await fetch(url, {method:'POST',headers:authHeaders(),body:JSON.stringify({printerId:_assignPrinterId})});
        const d = await r.json();
        if (r.ok) { showAlert('Assigned successfully','success'); document.getElementById('assignPrinterModal').classList.remove('active'); }
        else { showAlert(d.error||'Failed','error'); }
    } catch { showAlert('Failed','error'); }
}

// ── Faculty ───────────────────────────────────────────────────
let allFaculty = [];

async function loadFaculty() {
    try {
        const r = await fetch(API+'/admin/faculty', {headers:{'Authorization':`Bearer ${token}`}});
        allFaculty = await r.json();
        renderFaculty();
    } catch { showAlert('Failed to load faculty','error'); }
}

function renderFaculty() {
    const el = document.getElementById('facultyList');
    if (!el) return;
    if (!allFaculty.length) { el.innerHTML = `<div class="empty-state">No faculty yet.</div>`; return; }
    el.innerHTML = `<table class="data-table">
      <thead><tr><th>Name</th><th>Department</th><th>Email</th><th>Section</th><th>Printer</th><th>Actions</th></tr></thead>
      <tbody>${allFaculty.map(f => {
        const printer = allPrinters.find(p => p._id === f.assignedPrinterId);
        const sectionBadge = f.assignedSection
            ? `<span class="sec-tag" style="background:#e0f2fe;color:#0369a1">📚 ${f.assignedSection}</span>`
            : `<button class="btn btn-sm btn-warn" onclick="openAssignSectionModal('${f._id}','${f.name}','')">⚠️ Assign</button>`;
        return `<tr>
          <td><div class="student-name-cell"><div class="avatar" style="background:#7c3aed">${f.name[0]?.toUpperCase()||'?'}</div><strong>${f.name}</strong></div></td>
          <td>${f.department?`<span class="sec-tag" style="background:#ede9fe;color:#7c3aed">${f.department}</span>`:'—'}</td>
          <td class="muted">${f.email}</td>
          <td>${sectionBadge}</td>
          <td>${printer?`<span class="sec-tag" style="background:#d1fae5;color:#065f46">🖨️ ${printer.name}</span>`:'<span class="muted">Not assigned</span>'}</td>
          <td style="display:flex;gap:6px;flex-wrap:wrap">
            <button class="btn btn-sm" onclick="openAssignSectionModal('${f._id}','${f.name}','${f.assignedSection||''}')">
              ${f.assignedSection?'🔄 Section':'📚 Section'}
            </button>
            <button class="btn btn-sm" onclick="openAssignUserPrinter('${f._id}','${f.name}')">🖨️ Printer</button>
            <button class="btn btn-sm btn-red" onclick="deleteUser('${f._id}','${f.name}','faculty')">🗑️</button>
          </td>
        </tr>`;
      }).join('')}
      </tbody></table>`;
}

function openAssignUserPrinter(userId, userName) {
    _assignType = 'user';
    document.getElementById('assignPrinterTitle').textContent = `Assign Printer to "${userName}"`;
    document.getElementById('assignPrinterSub').textContent = 'This faculty will print to the selected printer.';
    const sel = document.getElementById('assignPrinterSelect');
    sel.innerHTML = '<option value="">— Remove assignment —</option>';
    allPrinters.forEach(p => sel.innerHTML += `<option value="${p._id}">🖨️ ${p.name}${p.isOnline?' ✅':''}</option>`);
    _assignPrinterId = ''; window._assignUserId = userId;
    document.getElementById('assignPrinterModal').classList.add('active');
}

const _origDoAssign = doAssignPrinter;
window.doAssignPrinter = async function() {
    if (window._assignUserId) {
        const printerId = document.getElementById('assignPrinterSelect').value;
        try {
            const r = await fetch(`${API}/admin/users/${window._assignUserId}/assign-printer`, {method:'POST',headers:authHeaders(),body:JSON.stringify({printerId})});
            const d = await r.json();
            if (r.ok) { showAlert('Printer assigned','success'); document.getElementById('assignPrinterModal').classList.remove('active'); window._assignUserId=null; await loadFaculty(); }
            else { showAlert(d.error||'Failed','error'); }
        } catch { showAlert('Failed','error'); }
    } else { await _origDoAssign(); }
};

function showAddFacultyModal() {
    document.getElementById('addFacultyName').value = '';
    document.getElementById('addFacultyEmail').value = '';
    document.getElementById('addFacultyPass').value = 'faculty123';
    document.getElementById('addFacultyDept').value = '';
    const sel = document.getElementById('addFacultyPrinter');
    sel.innerHTML = '<option value="">— Select printer —</option>';
    allPrinters.forEach(p => sel.innerHTML += `<option value="${p._id}">🖨️ ${p.name}</option>`);
    const secSel = document.getElementById('addFacultySection');
    if (secSel) { secSel.innerHTML = '<option value="">— No section —</option>'; allSections.forEach(s => secSel.innerHTML += `<option value="${s.name}">${s.name}</option>`); }
    document.getElementById('addFacultyModal').classList.add('active');
    setTimeout(() => document.getElementById('addFacultyName').focus(), 100);
}

async function createFaculty() {
    const name     = document.getElementById('addFacultyName').value.trim();
    const email    = document.getElementById('addFacultyEmail').value.trim();
    const password = document.getElementById('addFacultyPass').value;
    const dept     = document.getElementById('addFacultyDept').value.trim();
    const printer  = document.getElementById('addFacultyPrinter').value;
    const section  = document.getElementById('addFacultySection')?.value || '';
    if (!name || !email || password.length < 6) { showAlert('Fill all required fields (password min 6 chars)','error'); return; }
    try {
        const r = await fetch(API+'/admin/faculty', {method:'POST',headers:authHeaders(),body:JSON.stringify({name,email,password,department:dept,printerLocationId:printer,assignedSection:section})});
        const d = await r.json();
        if (r.ok) { showAlert(`Faculty "${name}" added`,'success'); document.getElementById('addFacultyModal').classList.remove('active'); await loadFaculty(); }
        else { showAlert(d.error||'Failed','error'); }
    } catch { showAlert('Failed','error'); }
}

function openAssignSectionModal(userId, userName, currentSection) {
    window._assignSectionUserId = userId;
    const existing = document.getElementById('assignSectionModal');
    if (existing) existing.remove();
    const opts = allSections.map(s => `<option value="${s.name}" ${s.name===currentSection?'selected':''}>${s.name}</option>`).join('');
    const modal = document.createElement('div');
    modal.id = 'assignSectionModal';
    modal.className = 'modal active';
    modal.innerHTML = `
      <div class="modal-box">
        <div class="modal-header"><h3>Assign Section — ${userName}</h3><button class="modal-close" onclick="document.getElementById('assignSectionModal').remove()">✕</button></div>
        <p class="modal-sub">Students in this section will appear on the faculty dashboard.</p>
        <div class="form-group"><label>Section</label><select id="assignSectionSelect"><option value="">— Remove section —</option>${opts}</select></div>
        <button class="btn btn-primary" onclick="doAssignSection()">Save</button>
      </div>`;
    document.body.appendChild(modal);
}

async function doAssignSection() {
    const sectionName = document.getElementById('assignSectionSelect').value;
    const userId = window._assignSectionUserId;
    if (!userId) return;
    try {
        const r = await fetch(`${API}/admin/users/${userId}/assign-section`, {method:'POST',headers:authHeaders(),body:JSON.stringify({sectionName})});
        const d = await r.json();
        if (r.ok) {
            showAlert(sectionName?`Section "${sectionName}" assigned ✅`:'Section removed','success');
            document.getElementById('assignSectionModal')?.remove();
            window._assignSectionUserId = null;
            await loadFaculty();
        } else { showAlert(d.error||'Failed','error'); }
    } catch { showAlert('Failed','error'); }
}

// Change password (shared between admin and student pages)
function showChangePasswordModal() {
    const modal = document.getElementById('changePassModal');
    if (!modal) return;
    document.getElementById('cpCurrent').value = '';
    document.getElementById('cpNew').value = '';
    document.getElementById('cpConfirm').value = '';
    modal.classList.add('active');
    setTimeout(() => document.getElementById('cpCurrent').focus(), 100);
}

async function submitChangePassword() {
    const cur  = document.getElementById('cpCurrent').value;
    const nw   = document.getElementById('cpNew').value;
    const conf = document.getElementById('cpConfirm').value;
    if (!cur || !nw) { showAlert('Fill all fields','error'); return; }
    if (nw.length < 6) { showAlert('New password must be at least 6 characters','error'); return; }
    if (nw !== conf) { showAlert('Passwords do not match','error'); return; }
    try {
        const r = await fetch(API+'/auth/change-password', {method:'POST',headers:authHeaders(),body:JSON.stringify({currentPassword:cur,newPassword:nw})});
        const d = await r.json();
        if (r.ok) {
            showAlert('Password changed successfully ✅','success');
            document.getElementById('changePassModal').classList.remove('active');
        } else { showAlert(d.error||'Failed','error'); }
    } catch { showAlert('Failed','error'); }
}

// ── Patch showAdminDashboard to load printers + faculty ───────
const _origShowAdmin = showAdminDashboard;
window.showAdminDashboard = async function() {
    await _origShowAdmin();
    await loadPrinters();
    await loadFaculty();
};
