# PrintHub — Complete Setup & Run Guide

Comprehensive documentation for running, configuring, and managing the **PrintHub (Smart Printing System)** project.

---

## 📌 Project Overview & Architecture

PrintHub consists of three primary components:

1. **Server & Web Portal (`server/`)**
   - **Backend**: Express.js REST API.
   - **Database**: MongoDB (Local or Atlas Cloud).
   - **Frontend**: Web-based Admin and Student Portal served at `http://localhost:3000`.
   - **Role**: Manages users, sections, pricing settings, print queue, and file uploads.

2. **Print Agent (`print-agent/`)**
   - **Technology**: Node.js service running on the PC connected to the physical printer.
   - **Role**: Continuously polls the server for queued jobs, downloads PDF files, and sends them directly to the Windows printer (`Brother DCP-T420W Printer` or system default).

3. **Mobile App (`printhub_app/`)**
   - **Technology**: Flutter (Android/iOS).
   - **Role**: Allows students to submit documents, pick print locations, and track prints from mobile devices.

---

## 🚀 Quick Start Guide (Step-by-Step)

### Prerequisites Check
Open PowerShell / Command Prompt and verify:
- **Node.js**: `node -v` (Node v18+ recommended)
- **MongoDB**: Make sure MongoDB service is running (`net start MongoDB` or verify port `27017` is active).

---

### Step 1: Start the Backend Server

1. Open PowerShell / Command Prompt in the project root:
   ```powershell
   cd s:\project2\printer
   ```

2. Start the server:
   ```powershell
   npm start
   ```
   *(Or run: `node server/server.js`)*

3. Verify:
   - Terminal shows:
     ```
     🚀 Server running on port 3000
     ✅ MongoDB connected
     ```
   - Open your web browser and go to: **[http://localhost:3000](http://localhost:3000)**

4. **Default Admin Login**:
   - **Email / Username**: `admin`
   - **Password**: `123456`

---

### Step 2: Configure & Start the Print Agent

The print agent needs to know which server to listen to and which printer to send jobs to.

#### A. Configure `print-agent/.env`
Open or edit `s:\project2\printer\print-agent\.env`:

```env
# If running server locally:
SERVER_URL=http://localhost:3000

# If using cloud Render server:
# SERVER_URL=https://print-agm.onrender.com

# Agent Key for your location (from Admin Panel -> Printers):
# Default seed key: printhub-agent-secret
# Or HOD location key: agent-vnxw4rudjyomog42toa
AGENT_KEY=agent-vnxw4rudjyomog42toa

# Exact printer name in Windows (or leave blank for default printer)
PRINTER_NAME=Brother DCP-T420W Printer
```

#### B. Start the Print Agent
You can start it using **either** of these methods:

- **Method 1 (Command Line)**:
  ```powershell
  cd s:\project2\printer
  node print-agent/printAgent.js
  ```
- **Method 2 (One-Click Batch File)**:
  - Double-click **`START-PRINTING.bat`**.

You will see:
```
==========================================
  PrintHub Print Agent
==========================================
Server  : http://localhost:3000
Printer : Brother DCP-T420W Printer
Polling : every 5 seconds

Waiting for print jobs...
```

---

### Step 3: Run the Mobile App (Optional)

If running the Flutter student app on an emulator or connected phone:

1. Navigate to the app directory:
   ```powershell
   cd s:\project2\printer\printhub_app
   ```
2. Fetch dependencies:
   ```powershell
   flutter pub get
   ```
3. Run the app:
   ```powershell
   flutter run
   ```

---

## 🛠️ Windows Automation Scripts Reference

In the root directory, several `.bat` files are prepared for printer workstations:

| Script | How to Run | What It Does |
|---|---|---|
| **`START-PRINTING.bat`** | Double-click | Starts the agent in an interactive green terminal window. |
| **`ADD-TO-STARTUP.bat`** | Double-click (Run once) | Adds a shortcut to the Windows Startup folder so the agent launches automatically upon user login. |
| **`REGISTER-TASK.bat`** | Right-click ➔ **Run as administrator** | Configures Windows Task Scheduler (`PrintHub-Agent`) to launch the agent silently at boot without requiring user login. |
| **`SETUP-PRINTER-PC.bat`** | Double-click | Interactive step-by-step wizard to setup a new printer PC, prompt for agent key & printer name, and register auto-start. |

---

## 📋 All Terminal Commands Cheat Sheet

```powershell
# --- Server Commands ---
npm start                              # Start server (from root s:\project2\printer)
node server/server.js                  # Direct node start for server

# --- Print Agent Commands ---
node print-agent/printAgent.js         # Start print agent manually
cd print-agent && npm install          # Install print-agent dependencies

# --- Flutter App Commands ---
cd printhub_app && flutter pub get     # Install Flutter packages
cd printhub_app && flutter run         # Run Flutter app on connected device

# --- Windows Printer & Service Check Commands ---
Get-Printer                            # List all Windows printers installed on the PC
Get-Service -Name *mongo*              # Check if MongoDB Windows service is running
net start MongoDB                      # Start MongoDB Windows service if stopped
```

---

## ⚠️ Troubleshooting & Common Issues

1. **"Cannot reach server — check internet" in Print Agent**:
   - Check if the server is running on `http://localhost:3000` (or `https://print-agm.onrender.com`).
   - Check that `SERVER_URL` in `print-agent/.env` matches where your server is running.

2. **"Unknown agent key" (HTTP 403)**:
   - Log into the Admin panel at `http://localhost:3000`.
   - Go to the **Printers** tab.
   - Copy the **Agent Key** for your printer location and paste it into `print-agent/.env` under `AGENT_KEY`.

3. **Wrong Printer Name**:
   - Run `Get-Printer` in PowerShell to find exact printer names.
   - Ensure `PRINTER_NAME` in `print-agent/.env` matches exactly (e.g., `Brother DCP-T420W Printer`). If left empty, Windows will use your default printer.

4. **MongoDB Connection Fails**:
   - Verify local MongoDB is running: `Test-NetConnection -ComputerName localhost -Port 27017`.
   - Start the service if needed: `net start MongoDB`.
