// ============================================================
//  PrintHub Web App
// ============================================================
let currentUser = null;
let token       = null;
let settings    = { pricePerPage:1, allowColor:true, allowDuplex:true, allowPageRange:true, allowPagesPerSheet:true, maxPagesPerJob:0 };
let allStudents = [];   // cached for search/filter
let allSections = [];   // cached sections list

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
async function apiFetch(url, opts = {}) {
    const r = await fetch(API + url, opts);
    return r;
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

function showRegisterPage() {
    document.getElementById('app').innerHTML = `
    <div class="auth-wrap">
      <div class="auth-card">
        <div class="auth-logo">
          <span class="logo-icon">🖨️</span>
          <h1>PrintHub</h1>
          <p>Create your account</p>
        </div>

        <form id="registerForm">
          <h2>Register</h2>
          <div class="form-group">
            <label>Full Name</label>
            <input type="text" id="regName" required placeholder="Your full name">
          </div>
          <div class="form-group">
            <label>Email</label>
            <input type="email" id="regEmail" required placeholder="Email address">
          </div>
          <div class="form-group">
            <label>Password</label>
            <div class="input-icon-wrap">
              <input type="password" id="regPass" required placeholder="Create password" minlength="6">
              <span class="toggle-pass" onclick="togglePass('regPass',this)">👁</span>
            </div>
          </div>
          <div class="form-group">
            <label>Section</label>
            <select id="regSection">
              <option value="">— Select section (optional) —</option>
            </select>
          </div>
          <button type="submit" class="btn btn-primary" id="regBtn">Create Account</button>
        </form>

        <div class="auth-toggle">
          Already have an account? <a href="#" onclick="showLoginPage()">Sign In</a>
        </div>
      </div>
    </div>
    <div id="alertContainer"></div>`;

    // Load sections into dropdown
    fetch(API + '/sections').then(r=>r.json()).then(secs => {
        const sel = document.getElementById('regSection');
        secs.forEach(s => sel.innerHTML += `<option value="${s.name}">${s.name}</option>`);
    });

    document.getElementById('registerForm').addEventListener('submit', async e => {
        e.preventDefault();
        const btn = document.getElementById('regBtn');
        btn.disabled = true; btn.textContent = 'Creating…';
        try {
            const r = await fetch(API + '/auth/register', {
                method:'POST', headers:{'Content-Type':'application/json'},
                body: JSON.stringify({
                    name:    document.getElementById('regName').value.trim(),
                    email:   document.getElementById('regEmail').value.trim(),
                    password:document.getElementById('regPass').value,
                    section: document.getElementById('regSection').value
                })
            });
            const d = await r.json();
            if (r.ok) { showAlert('Account created! Please sign in.','success'); setTimeout(showLoginPage,1500); }
            else { showAlert(d.error||'Registration failed','error'); }
        } catch { showAlert('Connection failed','error'); }
        btn.disabled = false; btn.textContent = 'Create Account';
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
//  STUDENT DASHBOARD
// ============================================================
async function showStudentDashboard() {
    await loadSettings();
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
        </div>
        <div class="topnav-right">
          <span class="nav-user">👤 ${currentUser.name}</span>
          <button class="btn-logout" onclick="logout()">Logout</button>
        </div>
      </nav>

      <div class="page-content">
        <div id="alertContainer"></div>

        <!-- Wallet card -->
        <div class="wallet-card">
          <div class="wallet-label">💰 Wallet Balance</div>
          <div class="wallet-amount">₹<span id="walletAmt">…</span></div>
          <div class="wallet-sub">₹<span id="priceDisplay">${settings.pricePerPage}</span> per page</div>
        </div>

        <!-- Upload card -->
        <div class="card">
          <h2 class="card-title">📄 Upload PDF to Print</h2>

          <!-- File picker -->
          <div class="file-drop" id="fileDrop" onclick="document.getElementById('pdfInput').click()">
            <input type="file" id="pdfInput" accept=".pdf" style="display:none">
            <div id="fileDropContent">
              <div class="file-drop-icon">📁</div>
              <div class="file-drop-text">Click to select PDF</div>
              <div class="file-drop-sub">PDF only · Max 50 MB</div>
            </div>
          </div>

          <!-- Print options -->
          <div class="print-options">
            <h3 class="options-title">Print Options</h3>

            <!-- Color mode -->
            ${settings.allowColor ? `
            <div class="option-row">
              <span class="option-label">🎨 Color Mode</span>
              <div class="chip-group">
                <button class="chip active" id="chip-bw"    onclick="selectChip('colorMode','bw',this)">B&amp;W</button>
                <button class="chip"        id="chip-color" onclick="selectChip('colorMode','color',this)">Color</button>
              </div>
            </div>` : ''}

            <!-- Duplex -->
            ${settings.allowDuplex ? `
            <div class="option-row">
              <span class="option-label">🔄 Duplex (Both Sides)</span>
              <label class="toggle-switch">
                <input type="checkbox" id="duplexCheck">
                <span class="toggle-slider"></span>
              </label>
            </div>` : ''}

            <!-- Pages per sheet -->
            ${settings.allowPagesPerSheet ? `
            <div class="option-row">
              <span class="option-label">📐 Pages per Sheet</span>
              <div class="chip-group">
                <button class="chip active" onclick="selectChip('pagesPerSheet','1',this)">1</button>
                <button class="chip"        onclick="selectChip('pagesPerSheet','2',this)">2</button>
                <button class="chip"        onclick="selectChip('pagesPerSheet','4',this)">4</button>
              </div>
            </div>` : ''}

            <!-- Page range -->
            ${settings.allowPageRange ? `
            <div class="option-row">
              <span class="option-label">📋 Custom Page Range</span>
              <label class="toggle-switch">
                <input type="checkbox" id="rangeCheck" onchange="toggleRangeInputs()">
                <span class="toggle-slider"></span>
              </label>
            </div>
            <div id="rangeInputs" style="display:none;" class="range-inputs">
              <input type="number" id="pageFrom" placeholder="From" min="1">
              <span>to</span>
              <input type="number" id="pageTo"   placeholder="To"   min="1">
            </div>` : ''}

            ${settings.maxPagesPerJob > 0 ? `<p class="option-note">⚠️ Max ${settings.maxPagesPerJob} pages per job</p>` : ''}
          </div>

          <button class="btn btn-primary btn-submit" onclick="submitPDF()">🖨️ Submit for Printing</button>
        </div>
      </div>
    </div>`;

    // Hidden state for chips
    window._printOpts = { colorMode:'bw', pagesPerSheet:'1' };

    document.getElementById('pdfInput').addEventListener('change', e => {
        const f = e.target.files[0];
        if (!f) return;
        if (f.size > 50*1024*1024) { showAlert('File too large (max 50MB)','error'); return; }
        document.getElementById('fileDropContent').innerHTML = `
          <div class="file-drop-icon">📄</div>
          <div class="file-drop-text file-selected">${f.name}</div>
          <div class="file-drop-sub">${(f.size/1024/1024).toFixed(2)} MB</div>`;
    });

    // Load wallet
    try {
        const r = await fetch(API+'/student/wallet',{headers:{'Authorization':`Bearer ${token}`}});
        const d = await r.json();
        document.getElementById('walletAmt').textContent = d.wallet ?? 0;
    } catch { document.getElementById('walletAmt').textContent = currentUser.wallet ?? 0; }
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

    const useRange = document.getElementById('rangeCheck')?.checked;
    const pageFrom = useRange ? (parseInt(document.getElementById('pageFrom')?.value)||0) : 0;
    const pageTo   = useRange ? (parseInt(document.getElementById('pageTo')?.value)||0)   : 0;
    if (useRange && (pageFrom <= 0 || pageTo < pageFrom)) {
        showAlert('Enter a valid page range','error'); return;
    }

    const fd = new FormData();
    fd.append('pdf',          input.files[0]);
    fd.append('colorMode',    window._printOpts.colorMode    || 'bw');
    fd.append('duplex',       document.getElementById('duplexCheck')?.checked || false);
    fd.append('pagesPerSheet',window._printOpts.pagesPerSheet || '1');
    fd.append('pageFrom',     pageFrom);
    fd.append('pageTo',       pageTo);

    // Progress overlay
    const overlay = document.createElement('div');
    overlay.className = 'progress-overlay';
    overlay.innerHTML = `
      <div class="progress-box">
        <div class="progress-icon">🖨️</div>
        <h3>Processing Print Job</h3>
        <div class="progress-bar-wrap"><div class="progress-fill" id="pFill"></div></div>
        <p id="pStatus">Uploading…</p>
      </div>`;
    document.body.appendChild(overlay);

    let pct = 0;
    const ticker = setInterval(() => {
        if (pct < 85) { pct += 3; document.getElementById('pFill').style.width = pct+'%'; document.getElementById('pStatus').textContent = `Uploading… ${pct}%`; }
    }, 200);

    try {
        const r = await fetch(API+'/upload', { method:'POST', headers:{'Authorization':`Bearer ${token}`}, body:fd });
        const d = await r.json();
        clearInterval(ticker);
        document.getElementById('pFill').style.width = '100%';
        document.getElementById('pStatus').textContent = r.ok ? '✅ Done!' : '❌ Failed';
        await new Promise(res => setTimeout(res, 700));
        overlay.remove();
        if (r.ok) {
            showAlert(`✅ Submitted! Pages: ${d.pages}, Cost: ₹${d.cost}, Balance: ₹${d.remainingWallet}`,'success');
            document.getElementById('walletAmt').textContent = d.remainingWallet;
            input.value = '';
            document.getElementById('fileDropContent').innerHTML = `
              <div class="file-drop-icon">📁</div>
              <div class="file-drop-text">Click to select PDF</div>
              <div class="file-drop-sub">PDF only · Max 50 MB</div>`;
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
          <button class="btn-logout" onclick="logout()">Logout</button>
        </div>
      </nav>

      <div class="admin-tabs">
        <button class="tab-btn active" onclick="switchTab('students',this)">👥 Students</button>
        <button class="tab-btn"        onclick="switchTab('jobs',this)">🖨️ Print Jobs</button>
        <button class="tab-btn"        onclick="switchTab('sections',this)">🗂️ Sections</button>
        <button class="tab-btn"        onclick="switchTab('settings',this)">⚙️ Settings</button>
      </div>

      <div class="page-content">
        <div id="alertContainer"></div>

        <!-- STUDENTS TAB -->
        <div id="tab-students" class="tab-panel">
          <div class="panel-header">
            <h2>👥 Students</h2>
            <span id="studentCount" class="count-badge">0</span>
            <div style="margin-left:auto">
              <button class="btn btn-primary btn-sm" onclick="showAddStudentModal()">+ Add Student</button>
            </div>
          </div>
          <!-- Search + section filter -->
          <div class="search-bar-wrap">
            <input type="text" id="studentSearch" placeholder="🔍 Search by name, email or section…" oninput="filterStudents()">
          </div>
          <div id="sectionFilterChips" class="chip-group filter-chips"></div>
          <div id="studentsList"></div>
        </div>

        <!-- PRINT JOBS TAB -->
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

        <!-- SECTIONS TAB -->
        <div id="tab-sections" class="tab-panel" style="display:none">
          <div class="panel-header">
            <h2>🗂️ Sections</h2>
            <button class="btn btn-primary btn-sm" onclick="showCreateSection()">+ New Section</button>
          </div>
          <div id="sectionsList"></div>
        </div>

        <!-- SETTINGS TAB -->
        <div id="tab-settings" class="tab-panel" style="display:none">
          <h2>⚙️ System Settings</h2>
          <div class="settings-grid">
            <div class="settings-card">
              <h3>💰 Pricing</h3>
              <div class="form-group">
                <label>Price per page (₹)</label>
                <input type="number" id="priceInput" min="0.5" step="0.5" value="${settings.pricePerPage}">
              </div>
              <div class="form-group">
                <label>Max pages per job (0 = unlimited)</label>
                <input type="number" id="maxPagesInput" min="0" value="${settings.maxPagesPerJob||0}">
              </div>
            </div>
            <div class="settings-card">
              <h3>🔒 Student Print Permissions</h3>
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
        <div class="modal-header">
          <h3>Add Wallet Funds</h3>
          <button class="modal-close" onclick="closeFundsModal()">✕</button>
        </div>
        <p id="fundsStudentName" class="modal-sub"></p>
        <div class="form-group">
          <label>Amount (₹)</label>
          <input type="number" id="fundsAmount" min="1" placeholder="Enter amount">
        </div>
        <button class="btn btn-primary" onclick="addFunds()">Add Funds</button>
      </div>
    </div>

    <!-- Create Section Modal -->
    <div id="sectionModal" class="modal">
      <div class="modal-box">
        <div class="modal-header">
          <h3>Create Section</h3>
          <button class="modal-close" onclick="closeSectionModal()">✕</button>
        </div>
        <p class="modal-sub">e.g. CSE, ECE, MECH, MBA</p>
        <div class="form-group">
          <label>Section Name</label>
          <input type="text" id="sectionNameInput" placeholder="e.g. CSE" style="text-transform:uppercase">
        </div>
        <button class="btn btn-primary" onclick="createSection()">Create</button>
      </div>
    </div>

    <!-- Add Student Modal -->
    <div id="addStudentModal" class="modal">
      <div class="modal-box">
        <div class="modal-header">
          <h3>Add Student</h3>
          <button class="modal-close" onclick="closeAddStudentModal()">✕</button>
        </div>
        <p class="modal-sub">Create a student account and assign to a section</p>
        <div class="form-group">
          <label>Full Name *</label>
          <input type="text" id="addStudentName" placeholder="Student full name">
        </div>
        <div class="form-group">
          <label>Email *</label>
          <input type="email" id="addStudentEmail" placeholder="student@email.com">
        </div>
        <div class="form-group">
          <label>Password *</label>
          <input type="password" id="addStudentPass" placeholder="Set a password" value="student123">
        </div>
        <div class="form-group">
          <label>Section</label>
          <select id="addStudentSection">
            <option value="">— No section —</option>
          </select>
        </div>
        <div class="form-group">
          <label>Initial Wallet Balance (₹)</label>
          <input type="number" id="addStudentWallet" placeholder="0" min="0" value="0">
        </div>
        <button class="btn btn-primary" onclick="createStudent()">Add Student</button>
      </div>
    </div>`;

    await loadStudents();
    await loadPrintJobs();
    renderSections();
}

function permToggle(id, label, checked) {
    return `<div class="perm-row">
      <span>${label}</span>
      <label class="toggle-switch">
        <input type="checkbox" id="perm-${id}" ${checked?'checked':''}>
        <span class="toggle-slider"></span>
      </label>
    </div>`;
}

function switchTab(name, btn) {
    document.querySelectorAll('.tab-panel').forEach(p => p.style.display='none');
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
    document.getElementById('tab-'+name).style.display = 'block';
    btn.classList.add('active');
}

// ── Students ──────────────────────────────────────────────────
let _activeSection = 'All';

async function loadStudents() {
    try {
        const r = await fetch(API+'/admin/students',{headers:{'Authorization':`Bearer ${token}`}});
        allStudents = await r.json();
        buildSectionChips();
        renderStudents();
        document.getElementById('studentCount').textContent = allStudents.length;
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
    const q   = (document.getElementById('studentSearch')?.value||'').toLowerCase();
    const list = allStudents.filter(s => {
        const matchSec = _activeSection==='All' || s.section===_activeSection;
        const matchQ   = !q || s.name.toLowerCase().includes(q) || s.email.toLowerCase().includes(q) || (s.section||'').toLowerCase().includes(q);
        return matchSec && matchQ;
    });

    const el = document.getElementById('studentsList');
    if (!el) return;
    if (!list.length) { el.innerHTML = `<div class="empty-state">No students found</div>`; return; }

    el.innerHTML = `<table class="data-table">
      <thead><tr><th>Name</th><th>Section</th><th>Email</th><th>Wallet</th><th>Action</th></tr></thead>
      <tbody>${list.map(s=>`
        <tr>
          <td><div class="student-name-cell"><div class="avatar" style="background:${sectionColor(s.section)}">${s.name[0]?.toUpperCase()||'?'}</div><strong>${s.name}</strong></div></td>
          <td>${s.section ? `<span class="sec-tag" style="background:${sectionColor(s.section)}20;color:${sectionColor(s.section)}">${s.section}</span>` : '—'}</td>
          <td class="muted">${s.email}</td>
          <td class="wallet-val">₹${s.wallet||0}</td>
          <td><button class="btn btn-sm btn-green" onclick="openFundsModal('${s._id}','${s.name}')">+ Funds</button></td>
        </tr>`).join('')}
      </tbody>
    </table>`;
}

const SECTION_COLORS = ['#6366f1','#06b6d4','#10b981','#f59e0b','#ef4444','#8b5cf6','#ec4899'];
function sectionColor(sec) {
    if (!sec) return '#94a3b8';
    return SECTION_COLORS[sec.charCodeAt(0) % SECTION_COLORS.length];
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
    // Populate section dropdown
    const sel = document.getElementById('addStudentSection');
    sel.innerHTML = '<option value="">— No section —</option>';
    allSections.forEach(s => sel.innerHTML += `<option value="${s.name}">${s.name}</option>`);
    // Clear fields
    document.getElementById('addStudentName').value   = '';
    document.getElementById('addStudentEmail').value  = '';
    document.getElementById('addStudentPass').value   = 'student123';
    document.getElementById('addStudentWallet').value = '0';
    document.getElementById('addStudentModal').classList.add('active');
    setTimeout(() => document.getElementById('addStudentName').focus(), 100);
}

function closeAddStudentModal() {
    document.getElementById('addStudentModal').classList.remove('active');
}

async function createStudent() {
    const name    = document.getElementById('addStudentName').value.trim();
    const email   = document.getElementById('addStudentEmail').value.trim();
    const password= document.getElementById('addStudentPass').value;
    const section = document.getElementById('addStudentSection').value;
    const wallet  = parseInt(document.getElementById('addStudentWallet').value) || 0;

    if (!name)     { showAlert('Name is required','error'); return; }
    if (!email)    { showAlert('Email is required','error'); return; }
    if (!password || password.length < 6) { showAlert('Password must be at least 6 characters','error'); return; }

    try {
        const r = await fetch(API+'/admin/students', {
            method: 'POST', headers: authHeaders(),
            body: JSON.stringify({ name, email, password, section, wallet })
        });
        const d = await r.json();
        if (r.ok) {
            showAlert(`Student "${name}" added successfully`, 'success');
            closeAddStudentModal();
            loadStudents();
        } else {
            showAlert(d.error || 'Failed to create student', 'error');
        }
    } catch { showAlert('Failed to create student', 'error'); }
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
    const list = allJobs.filter(j => !q || j.fileName.toLowerCase().includes(q) || j.studentName.toLowerCase().includes(q));
    const el = document.getElementById('jobsList');
    if (!el) return;
    if (!list.length) { el.innerHTML = `<div class="empty-state">No print jobs yet</div>`; return; }

    el.innerHTML = list.map(j => {
        const statusCls = { pending:'badge-warn', printing:'badge-info', completed:'badge-ok', failed:'badge-err' }[j.status] || 'badge-warn';
        const opts = [
            j.colorMode === 'color' ? '🎨 Color' : '⬛ B&W',
            j.duplex ? '🔄 Duplex' : '📄 Simplex',
            j.pagesPerSheet > 1 ? `${j.pagesPerSheet}up` : '',
            j.pageRangeFrom > 0 ? `p${j.pageRangeFrom}-${j.pageRangeTo}` : ''
        ].filter(Boolean).join(' · ');
        return `<div class="job-card">
          <div class="job-header">
            <div>
              <div class="job-filename">📄 ${j.fileName}</div>
              <div class="job-meta">${j.studentName}${j.studentSection?' · '+j.studentSection:''} · ${new Date(j.createdAt).toLocaleString()}</div>
            </div>
            <span class="badge ${statusCls}">${j.status.toUpperCase()}</span>
          </div>
          <div class="job-details">
            <span>📃 ${j.pages} pages</span>
            <span>₹${j.cost}</span>
            <span class="muted">${opts}</span>
          </div>
        </div>`;
    }).join('');
}

// ── Sections ──────────────────────────────────────────────────
async function loadSections() {
    try {
        const r = await fetch(API+'/sections');
        allSections = await r.json();
    } catch { allSections = []; }
}

function renderSections() {
    const el = document.getElementById('sectionsList');
    if (!el) return;
    if (!allSections.length) { el.innerHTML = `<div class="empty-state">No sections yet. Create one!</div>`; return; }
    el.innerHTML = `<div class="sections-grid">${allSections.map(s=>`
      <div class="section-card">
        <div class="section-icon" style="background:${sectionColor(s.name)}20;color:${sectionColor(s.name)}">🗂️</div>
        <div class="section-name">${s.name}</div>
        <div class="section-count">${allStudents.filter(st=>st.section===s.name).length} students</div>
        <button class="btn btn-sm btn-red" onclick="deleteSection('${s._id}','${s.name}')">Delete</button>
      </div>`).join('')}
    </div>`;
}

function showCreateSection() {
    document.getElementById('sectionNameInput').value = '';
    document.getElementById('sectionModal').classList.add('active');
    setTimeout(()=>document.getElementById('sectionNameInput').focus(),100);
}
function closeSectionModal() { document.getElementById('sectionModal').classList.remove('active'); }

async function createSection() {
    const name = document.getElementById('sectionNameInput').value.trim().toUpperCase();
    if (!name) { showAlert('Enter a section name','error'); return; }
    try {
        const r = await fetch(API+'/admin/sections',{method:'POST',headers:authHeaders(),body:JSON.stringify({name})});
        const d = await r.json();
        if (r.ok) { showAlert(`Section "${name}" created`,'success'); closeSectionModal(); await loadSections(); renderSections(); buildSectionChips(); }
        else { showAlert(d.error||'Failed','error'); }
    } catch { showAlert('Failed to create section','error'); }
}

async function deleteSection(id, name) {
    if (!confirm(`Delete section "${name}"? Students won't be affected.`)) return;
    try {
        const r = await fetch(API+'/admin/sections/'+id,{method:'DELETE',headers:authHeaders()});
        if (r.ok) { showAlert(`"${name}" deleted`,'success'); await loadSections(); renderSections(); buildSectionChips(); }
        else { showAlert('Failed to delete','error'); }
    } catch { showAlert('Failed','error'); }
}

// ── Settings ──────────────────────────────────────────────────
async function loadSettings() {
    try {
        const r = await fetch(API+'/settings');
        settings = await r.json();
    } catch { /* use defaults */ }
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
    } catch { showAlert('Failed to save','error'); }
}
