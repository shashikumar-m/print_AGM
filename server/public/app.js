let currentUser = null;
let token = null;
let settings = { pricePerPage: 1 }; // Global settings

// API Base URL
const API_URL = window.location.origin + '/api';

// ============ INITIALIZATION ============
document.addEventListener('DOMContentLoaded', () => {
    const savedToken = localStorage.getItem('token');
    if (savedToken) {
        token = savedToken;
        currentUser = JSON.parse(localStorage.getItem('user'));
        showDashboard();
    } else {
        showLoginPage();
    }

    setupEventListeners();
});

// ============ EVENT LISTENERS ============
function setupEventListeners() {
    // Login form
    const loginForm = document.getElementById('loginForm');
    if (loginForm) loginForm.addEventListener('submit', handleLogin);

    // Register form
    const registerForm = document.getElementById('registerForm');
    if (registerForm) registerForm.addEventListener('submit', handleRegister);

    // Toggle between login and register
    const toggleBtn = document.getElementById('toggleBtn');
    if (toggleBtn) {
        toggleBtn.addEventListener('click', (e) => {
            e.preventDefault();
            toggleAuthForms();
        });
    }
}

// ============ AUTHENTICATION ============
async function handleLogin(e) {
    e.preventDefault();

    const email = document.getElementById('loginEmail').value;
    const password = document.getElementById('loginPassword').value;

    try {
        const response = await fetch(`${API_URL}/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, password })
        });

        const data = await response.json();

        if (response.ok) {
            token = data.token;
            currentUser = data.user;
            localStorage.setItem('token', token);
            localStorage.setItem('user', JSON.stringify(currentUser));
            showDashboard();
        } else {
            showAlert(data.error, 'error');
        }
    } catch (err) {
        showAlert('Login failed', 'error');
    }
}

async function handleRegister(e) {
    e.preventDefault();

    const name = document.getElementById('registerName').value;
    const email = document.getElementById('registerEmail').value;
    const password = document.getElementById('registerPassword').value;

    try {
        const response = await fetch(`${API_URL}/auth/register`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name, email, password })
        });

        const data = await response.json();

        if (response.ok) {
            showAlert('Registration successful! Please login.', 'success');
            setTimeout(() => toggleAuthForms(), 1500);
        } else {
            showAlert(data.error, 'error');
        }
    } catch (err) {
        showAlert('Registration failed', 'error');
    }
}

function toggleAuthForms() {
    const loginForm = document.getElementById('loginForm');
    const registerForm = document.getElementById('registerForm');
    const toggleText = document.getElementById('toggleText');

    if (loginForm.style.display === 'none') {
        loginForm.style.display = 'block';
        registerForm.style.display = 'none';
        toggleText.innerHTML = "Don't have an account? <a href='#' id='toggleBtn'>Register</a>";
    } else {
        loginForm.style.display = 'none';
        registerForm.style.display = 'block';
        toggleText.innerHTML = "Already have an account? <a href='#' id='toggleBtn'>Login</a>";
    }

    setupEventListeners();
}

// ============ DASHBOARD SWITCHING ============
function showLoginPage() {
    document.body.innerHTML = `
        <div class="container">
            <div class="login-container">
                <div class="logo">
                    <h1>🖨️ PrintHub</h1>
                    <p>Smart Student Printing System</p>
                </div>

                <form id="loginForm" class="form-section">
                    <h2>Login</h2>
                    <div class="form-group">
                        <label>Email</label>
                        <input type="email" id="loginEmail" required placeholder="Enter your email">
                    </div>
                    <div class="form-group">
                        <label>Password</label>
                        <input type="password" id="loginPassword" required placeholder="Enter your password">
                    </div>
                    <button type="submit" class="btn btn-primary">Login</button>
                </form>

                <form id="registerForm" class="form-section" style="display:none;">
                    <h2>Create Account</h2>
                    <div class="form-group">
                        <label>Name</label>
                        <input type="text" id="registerName" required placeholder="Full name">
                    </div>
                    <div class="form-group">
                        <label>Email</label>
                        <input type="email" id="registerEmail" required placeholder="Email address">
                    </div>
                    <div class="form-group">
                        <label>Password</label>
                        <input type="password" id="registerPassword" required placeholder="Create password">
                    </div>
                    <button type="submit" class="btn btn-primary">Register</button>
                </form>

                <div class="form-toggle">
                    <p id="toggleText">Don't have an account? <a href="#" id="toggleBtn">Register</a></p>
                </div>

                <div class="demo-section">
                    <h3>Demo Credentials</h3>
                    <p><strong>Admin:</strong> admin@example.com / admin123</p>
                    <p><strong>Student:</strong> student@example.com / student123</p>
                </div>
            </div>
        </div>
        <div id="alertContainer"></div>
    `;
    setupEventListeners();
}

function showDashboard() {
    if (currentUser.role === 'admin') {
        showAdminDashboard();
    } else {
        showStudentDashboard();
    }
}

async function showStudentDashboard() {
    document.body.innerHTML = `
        <div class="dashboard">
            <div class="nav-top">
                <h1>🖨️ Student Dashboard</h1>
                <div>
                    <span style="margin-right: 20px;">Welcome, ${currentUser.name}</span>
                    <button onclick="logout()">Logout</button>
                </div>
            </div>
            <div class="dashboard-content">
                <div id="alertContainer"></div>
                
                <div class="wallet-card">
                    <h2>💰 Your Wallet Balance</h2>
                    <div class="wallet-amount"><span>₹</span><span id="walletAmount">0</span></div>
                    <p>Price: ₹<span id="pricePerPage">1</span> per page</p>
                </div>

                <div class="upload-section">
                    <h2>📄 Upload PDF to Print</h2>
                    
                    <div class="file-input-wrapper">
                        <input type="file" id="pdfFile" accept=".pdf" />
                        <p onclick="document.getElementById('pdfFile').click()">📁 Click to upload PDF</p>
                        <div class="file-name" id="fileName"></div>
                    </div>

                    <div id="costSummary" style="display: none;">
                        <div class="cost-summary">
                            <p><strong>Pages:</strong> <span id="pageCount">0</span></p>
                            <p><strong>Cost:</strong> ₹<span id="costAmount">0</span></p>
                            <p><strong>After Print Balance:</strong> ₹<span id="afterBalance">0</span></p>
                        </div>
                    </div>

                    <div class="upload-options">
                        <label>
                            <input type="checkbox" id="duplexCheckbox" />
                            Print on both sides (Duplex)
                        </label>
                    </div>

                    <button class="btn-upload" id="submitBtn" onclick="submitPDF()">Submit for Printing</button>
                </div>
            </div>
        </div>
    `;

    // Load settings and wallet
    await loadSettings();
    document.getElementById('pricePerPage').textContent = settings.pricePerPage;
    await loadStudentWallet();

    // Setup file upload
    document.getElementById('pdfFile').addEventListener('change', handleFileSelect);
}

async function showAdminDashboard() {
    document.body.innerHTML = `
        <div class="dashboard">
            <div class="nav-top">
                <h1>⚙️ Admin Dashboard</h1>
                <div>
                    <span style="margin-right: 20px;">Welcome, Admin</span>
                    <button onclick="logout()">Logout</button>
                </div>
            </div>
            <div class="dashboard-content">
                <div id="alertContainer"></div>
                
                <!-- Tab Navigation -->
                <div class="tab-navigation">
                    <button class="tab-btn active" onclick="switchAdminTab('students')">👥 Students</button>
                    <button class="tab-btn" onclick="switchAdminTab('jobs')">🖨️ Print Jobs</button>
                    <button class="tab-btn" onclick="switchAdminTab('settings')">⚙️ Settings</button>
                </div>

                <div class="admin-container">
                    <!-- Students Section -->
                    <div class="admin-section" id="studentsTab">
                        <h2>👥 Manage Students</h2>
                        <div id="studentsList"></div>
                    </div>

                    <!-- Print Jobs Section -->
                    <div class="admin-section" id="jobsTab" style="display:none;">
                        <h2>🖨️ Print Jobs</h2>
                        <div id="printJobsList"></div>
                    </div>

                    <!-- Settings Section -->
                    <div class="admin-section" id="settingsTab" style="display:none;">
                        <h2>⚙️ System Settings</h2>
                        <div class="settings-form">
                            <div class="input-group">
                                <label>Price Per Page (₹)</label>
                                <div style="display: flex; gap: 10px;">
                                    <input type="number" id="priceInput" min="0.5" step="0.5" placeholder="Enter price">
                                    <button class="btn btn-primary" onclick="updatePrice()" style="width: 150px;">Update Price</button>
                                </div>
                            </div>
                            <div style="margin-top: 20px; padding: 15px; background: #f0f0ff; border-radius: 8px;">
                                <p><strong>Current Price:</strong> ₹<span id="currentPrice">1</span> per page</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Modal for adding wallet -->
        <div id="walletModal" class="modal">
            <div class="modal-content">
                <button class="modal-close" onclick="closeWalletModal()">✕</button>
                <h2>Add Wallet Amount</h2>
                <div class="input-group">
                    <label>Student</label>
                    <select id="studentSelect"></select>
                </div>
                <div class="input-group">
                    <label>Amount (₹)</label>
                    <input type="number" id="amountInput" min="1" placeholder="Enter amount">
                </div>
                <button class="btn btn-primary" onclick="addWallet()">Add to Wallet</button>
            </div>
        </div>
    `;

    // Load settings first
    await loadSettings();
    document.getElementById('priceInput').value = settings.pricePerPage;
    document.getElementById('currentPrice').textContent = settings.pricePerPage;

    // Load students and print jobs
    await loadStudents();
    await loadPrintJobs();
}

// ============ STUDENT FUNCTIONS ============
async function loadStudentWallet() {
    try {
        const response = await fetch(`${API_URL}/student/wallet`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        const data = await response.json();
        document.getElementById('walletAmount').textContent = data.wallet;
        currentUser.wallet = data.wallet;
    } catch (err) {
        showAlert('Failed to load wallet', 'error');
    }
}

function handleFileSelect(e) {
    const file = e.target.files[0];
    if (!file) return;

    document.getElementById('fileName').textContent = `Selected: ${file.name}`;
    // File size validation
    if (file.size > 50 * 1024 * 1024) {
        showAlert('File too large (max 50MB)', 'error');
        return;
    }
}

async function submitPDF() {
    const fileInput = document.getElementById('pdfFile');
    if (!fileInput.files[0]) {
        showAlert('Please select a PDF file', 'error');
        return;
    }

    const file = fileInput.files[0];
    const formData = new FormData();
    formData.append('pdf', file);
    formData.append('duplex', document.getElementById('duplexCheckbox').checked);

    // Show progress indicator
    const progressContainer = document.createElement('div');
    progressContainer.id = 'printProgress';
    progressContainer.innerHTML = `
        <div class="progress-overlay">
            <div class="progress-content">
                <h3>🖨️ Printing in Progress</h3>
                <div class="page-counter">
                    <div class="page-display" id="pageDisplay">Page 1</div>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" id="progressFill"></div>
                </div>
                <p id="statusText">Preparing to print...</p>
            </div>
        </div>
    `;
    document.body.appendChild(progressContainer);

    // Simulate page progress
    const updateProgress = (currentPage, totalPages) => {
        const percentage = (currentPage / totalPages) * 100;
        document.getElementById('pageDisplay').textContent = `Page ${currentPage}/${totalPages}`;
        document.getElementById('progressFill').style.width = percentage + '%';
        document.getElementById('statusText').textContent = `Printing page ${currentPage} of ${totalPages}...`;
    };

    // Start simulated progress
    let currentPage = 1;
    const progressInterval = setInterval(() => {
        if (currentPage < 100) {
            updateProgress(currentPage, 100);
            currentPage += Math.random() * 15;
        }
    }, 300);

    try {
        const response = await fetch(`${API_URL}/upload`, {
            method: 'POST',
            headers: { 'Authorization': `Bearer ${token}` },
            body: formData
        });

        const data = await response.json();

        clearInterval(progressInterval);

        if (response.ok) {
            // Show final progress
            updateProgress(data.pages, data.pages);
            document.getElementById('statusText').textContent = `Success! ${data.pages} pages will be printed.`;
            
            setTimeout(() => {
                progressContainer.remove();
                showAlert(`✅ Success! Pages: ${data.pages}, Cost: ₹${data.cost}, Remaining: ₹${data.remainingWallet}`, 'success');
                document.getElementById('walletAmount').textContent = data.remainingWallet;
                fileInput.value = '';
                document.getElementById('fileName').textContent = '';
                document.getElementById('costSummary').style.display = 'none';
            }, 1500);
        } else {
            progressContainer.remove();
            showAlert(data.error, 'error');
        }
    } catch (err) {
        clearInterval(progressInterval);
        progressContainer.remove();
        showAlert('Upload failed', 'error');
    }
            showAlert(data.error, 'error');
        }
    } catch (err) {
        showAlert('Upload failed', 'error');
    }
}

// ============ ADMIN FUNCTIONS ============
async function loadStudents() {
    try {
        const response = await fetch(`${API_URL}/admin/students`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        const students = await response.json();

        let html = '';
        students.forEach(student => {
            html += `
                <div class="student-item">
                    <div class="student-info">
                        <h3>${student.name}</h3>
                        <p>${student.email}</p>
                    </div>
                    <div class="wallet-display">₹${student.wallet}</div>
                    <button class="btn-add-wallet" onclick="openWalletModal('${student.id}', '${student.name}')">Add Wallet</button>
                </div>
            `;
        });

        document.getElementById('studentsList').innerHTML = html;
    } catch (err) {
        showAlert('Failed to load students', 'error');
    }
}

async function loadPrintJobs() {
    try {
        const response = await fetch(`${API_URL}/admin/print-jobs`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        const jobs = await response.json();

        let html = '';
        if (jobs.length === 0) {
            html = '<p style="color: #999;">No print jobs yet</p>';
        } else {
            jobs.forEach(job => {
                let statusClass = `status-${job.status}`;
                html += `
                    <div class="print-job">
                        <h4>${job.fileName}</h4>
                        <p><strong>Student:</strong> ${job.studentName}</p>
                        <p><strong>Pages:</strong> ${job.pages}</p>
                        <p><strong>Cost:</strong> ₹${job.cost}</p>
                        <p><strong>Mode:</strong> ${job.duplex ? 'Duplex' : 'Simplex'}</p>
                        <span class="status-badge ${statusClass}">${job.status.toUpperCase()}</span>
                    </div>
                `;
            });
        }

        document.getElementById('printJobsList').innerHTML = html;
    } catch (err) {
        showAlert('Failed to load print jobs', 'error');
    }
}

function openWalletModal(studentId, studentName) {
    document.getElementById('walletModal').classList.add('active');
    document.getElementById('studentSelect').value = studentId;
}

function closeWalletModal() {
    document.getElementById('walletModal').classList.remove('active');
}

async function addWallet() {
    const studentId = document.getElementById('studentSelect').value;
    const amount = parseInt(document.getElementById('amountInput').value);

    if (!amount || amount <= 0) {
        showAlert('Enter valid amount', 'error');
        return;
    }

    try {
        const response = await fetch(`${API_URL}/admin/add-wallet`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${token}`
            },
            body: JSON.stringify({ studentId, amount })
        });

        const data = await response.json();

        if (response.ok) {
            showAlert(`Wallet updated! New balance: ₹${data.wallet}`, 'success');
            closeWalletModal();
            loadStudents();
        } else {
            showAlert(data.error, 'error');
        }
    } catch (err) {
        showAlert('Failed to update wallet', 'error');
    }
}

// ============ SETTINGS FUNCTIONS ============
async function loadSettings() {
    try {
        const response = await fetch(`${API_URL}/settings`);
        settings = await response.json();
    } catch (err) {
        console.log('Failed to load settings, using defaults');
    }
}

async function updatePrice() {
    const price = parseFloat(document.getElementById('priceInput').value);
    
    if (!price || price <= 0) {
        showAlert('Enter valid price', 'error');
        return;
    }

    try {
        const response = await fetch(`${API_URL}/admin/settings`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${token}`
            },
            body: JSON.stringify({ pricePerPage: price })
        });

        const data = await response.json();

        if (response.ok) {
            settings = data.settings;
            document.getElementById('currentPrice').textContent = price;
            showAlert(`Price updated to ₹${price} per page`, 'success');
        } else {
            showAlert(data.error, 'error');
        }
    } catch (err) {
        showAlert('Failed to update price', 'error');
    }
}

function switchAdminTab(tab) {
    // Hide all tabs
    document.getElementById('studentsTab').style.display = 'none';
    document.getElementById('jobsTab').style.display = 'none';
    document.getElementById('settingsTab').style.display = 'none';
    
    // Remove active class from all buttons
    document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
    
    // Show selected tab
    if (tab === 'students') {
        document.getElementById('studentsTab').style.display = 'block';
        document.querySelectorAll('.tab-btn')[0].classList.add('active');
    } else if (tab === 'jobs') {
        document.getElementById('jobsTab').style.display = 'block';
        document.querySelectorAll('.tab-btn')[1].classList.add('active');
    } else if (tab === 'settings') {
        document.getElementById('settingsTab').style.display = 'block';
        document.querySelectorAll('.tab-btn')[2].classList.add('active');
    }
}

// ============ UTILITIES ============
function logout() {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    token = null;
    currentUser = null;
    showLoginPage();
}

function showAlert(message, type = 'info') {
    const container = document.getElementById('alertContainer') || createAlertContainer();
    
    const alert = document.createElement('div');
    alert.className = `alert alert-${type} show`;
    alert.textContent = message;
    
    container.innerHTML = '';
    container.appendChild(alert);

    setTimeout(() => {
        alert.classList.remove('show');
    }, 4000);
}

function createAlertContainer() {
    const container = document.createElement('div');
    container.id = 'alertContainer';
    document.body.appendChild(container);
    return container;
}
