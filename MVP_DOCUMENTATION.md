# Lab Manager - Full MVP Documentation

**Version:** 1.0.0
**Status:** Production Ready
**Date:** 2025-11-19

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Features](#features)
4. [Installation](#installation)
5. [Configuration](#configuration)
6. [Usage](#usage)
7. [API Documentation](#api-documentation)
8. [Deployment](#deployment)
9. [Security](#security)
10. [Troubleshooting](#troubleshooting)

---

## Overview

Lab Manager is a comprehensive, production-ready platform for deploying and managing Linux system administration training labs on Proxmox VE. It provides automated VM deployment, lab execution, and grading with a modern web interface and robust backend API.

### Key Capabilities

- **Automated VM Deployment**: Deploy CentOS Stream 9/RHEL 9 lab environments via web interface
- **Lab Execution**: SSH-based remote execution of training labs with automated verification
- **Grading System**: Comprehensive pass/fail grading with improvement tracking
- **User Management**: Multi-user support with role-based access control
- **RESTful API**: Full-featured API for integration and automation
- **Background Processing**: Async task execution with Celery
- **Database Tracking**: Persistent storage of deployments and results

---

## Architecture

### Technology Stack

#### Frontend
- **HTML5/CSS3/JavaScript** - Modern, responsive web interface
- **Fetch API** - RESTful API communication
- **No external dependencies** - Lightweight and fast

#### Backend
- **Flask 3.0** - Python web framework
- **SQLAlchemy** - ORM for database operations
- **Flask-Login** - Session management and authentication
- **Celery** - Distributed task queue for background jobs
- **Redis** - Message broker and caching

#### Infrastructure
- **Proxmox VE** - Virtualization platform
- **PostgreSQL/SQLite** - Database options
- **Nginx** - Reverse proxy (optional)
- **Docker** - Containerization support
- **Systemd** - Service management

### System Architecture

```
┌─────────────────┐
│   Web Browser   │
└────────┬────────┘
         │ HTTPS
         ▼
┌─────────────────┐      ┌──────────────┐
│  Nginx (Proxy)  │──────│   Flask API  │
└─────────────────┘      └──────┬───────┘
                                │
                    ┌───────────┼───────────┐
                    │           │           │
                    ▼           ▼           ▼
            ┌────────────┐ ┌────────┐ ┌─────────┐
            │ PostgreSQL │ │ Redis  │ │ Proxmox │
            └────────────┘ └────┬───┘ └─────────┘
                                │
                                ▼
                        ┌───────────────┐
                        │ Celery Worker │
                        └───────────────┘
```

### Database Schema

**Users Table**
- id, username, email, password_hash
- is_admin, is_active
- created_at, last_login

**Deployments Table**
- id, user_id, template_name, node
- status, vm_ids, created_at, completed_at
- storage, network_bridge, vm_prefix, error_message

**LabResults Table**
- id, user_id, deployment_id, student_name
- vm_ip, lab_type, status, executed_at
- total_tasks, passed_tasks, failed_tasks
- execution_time, report paths

---

## Features

### 1. Web Interface

**Login System**
- Secure authentication with bcrypt password hashing
- Session-based login with Flask-Login
- Admin and regular user roles

**VM Deployment**
- Two lab templates (Base: 1 server + 1 client, Extended: 1 server + 2 clients)
- Real-time deployment progress tracking
- VM management (start, stop, console access)

**Results Dashboard**
- View all lab executions and results
- Downloadable reports (text, JSON, HTML)
- Historical tracking and trends

### 2. Backend API

**RESTful Endpoints**
- `/api/auth/*` - Authentication operations
- `/api/proxmox/*` - Proxmox integration
- `/api/deployments` - VM deployment management
- `/api/results` - Lab results access
- `/api/health` - Health monitoring

**Security Features**
- CORS protection with configurable origins
- Input validation and sanitization
- SQL injection prevention
- XSS protection
- Password hashing with pbkdf2:sha256
- Session management

### 3. Background Processing

**Celery Tasks**
- `deploy_lab_environment` - Async VM deployment
- `execute_lab` - Remote lab execution
- `cleanup_old_deployments` - Automated cleanup

**Task Queue**
- Redis-backed message queue
- Task status tracking
- Retry mechanisms
- Concurrency control

### 4. Lab Execution

**Automated Workflows**
- Creation phase: Generate lab environments
- Checking phase: Verify student work
- Grading phase: Generate comprehensive reports

**Security Hardening**
- Input validation (IP addresses, ports, usernames)
- Command injection prevention
- Path traversal protection
- Secure credential handling (SSHPASS environment variable)
- Proper variable quoting

### 5. Grading System

**Pass/Fail Tracking**
- Task-level grading
- Attempt tracking
- Improvement metrics
- Multiple output formats

**Report Types**
- **Text**: Human-readable console output
- **JSON**: Machine-readable for automation
- **HTML**: Web-viewable with visualizations

---

## Installation

### Prerequisites

- Linux server (Ubuntu 20.04+, RHEL 8+, CentOS Stream 9+)
- Python 3.9+
- Redis server
- PostgreSQL 12+ (or use SQLite for development)
- Proxmox VE 7.0+
- SSH access to Proxmox host

### Quick Start

```bash
# Clone repository
git clone https://github.com/JLATORRE89/labManager.git
cd labManager

# Run automated installation
chmod +x setup.sh
./setup.sh
```

The setup script will:
1. Install system dependencies
2. Create Python virtual environment
3. Install Python packages
4. Generate .env configuration
5. Initialize database
6. Create systemd services
7. Configure firewall

### Manual Installation

```bash
# Install system dependencies (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv redis-server sshpass

# Install system dependencies (RHEL/CentOS)
sudo dnf install -y python3 python3-pip redis sshpass

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python packages
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your settings

# Initialize database
python3 -c "from app import init_database; init_database()"

# Start Redis
sudo systemctl start redis

# Run application
python3 app.py
```

### Docker Deployment

```bash
# Copy and configure environment
cp .env.example .env
# Edit .env with your settings

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

---

## Configuration

### Environment Variables

Edit `.env` file with your settings:

```bash
# Application
SECRET_KEY=generate-a-random-secret-key-here
FLASK_ENV=production

# Database
DATABASE_URL=postgresql://user:pass@localhost/labmanager
# Or for SQLite: sqlite:///labmanager.db

# Proxmox Configuration
PROXMOX_HOST=https://proxmox.example.com:8006
PROXMOX_USER=root@pam
PROXMOX_TOKEN_NAME=labmanager
PROXMOX_TOKEN_VALUE=your-token-value
PROXMOX_VERIFY_SSL=false

# Redis
REDIS_URL=redis://localhost:6379/0

# Admin User
ADMIN_USERNAME=admin
ADMIN_PASSWORD=change-this-password
ADMIN_EMAIL=admin@example.com

# Settings
MAX_CONCURRENT_DEPLOYMENTS=5
VM_DEPLOYMENT_TIMEOUT=600
LAB_EXECUTION_TIMEOUT=300
```

### Proxmox API Token

Create a token in Proxmox:

```bash
# In Proxmox web UI:
# Datacenter → Permissions → API Tokens → Add
# User: root@pam
# Token ID: labmanager
# Copy the secret value to .env
```

---

## Usage

### Starting Services

**Development Mode:**
```bash
# Terminal 1: Flask API
source venv/bin/activate
python3 app.py

# Terminal 2: Celery worker
source venv/bin/activate
celery -A tasks worker --loglevel=info
```

**Production Mode (systemd):**
```bash
sudo systemctl start labmanager-api
sudo systemctl start labmanager-celery

# Enable on boot
sudo systemctl enable labmanager-api
sudo systemctl enable labmanager-celery

# Check status
sudo systemctl status labmanager-api
sudo systemctl status labmanager-celery
```

**Docker:**
```bash
docker-compose up -d
```

### Accessing the Application

1. **Open web browser:** `http://your-server:5000`
2. **Login:** Default credentials: admin / admin
3. **Deploy VMs:** Select template and configure deployment
4. **Run Labs:** Execute labs on deployed VMs
5. **View Results:** Check completed labs and reports

### API Usage

```bash
# Login
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}' \
  -c cookies.txt

# List deployments
curl http://localhost:5000/api/deployments \
  -b cookies.txt

# Create deployment
curl -X POST http://localhost:5000/api/deployments \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{
    "template": "rhcsa9-base",
    "node": "pve",
    "storage": "local-lvm",
    "bridge": "vmbr0",
    "prefix": "rhcsa9-"
  }'
```

---

## API Documentation

### Authentication Endpoints

**POST /api/auth/login**
- Login with username and password
- Returns: User object and session cookie

**POST /api/auth/logout**
- Logout current user
- Requires: Authentication

**GET /api/auth/status**
- Check authentication status
- Returns: User object if authenticated

### Proxmox Endpoints

**POST /api/proxmox/connect**
- Test Proxmox connection
- Body: `{host, token_id, token_secret}`

**GET /api/proxmox/nodes**
- List Proxmox nodes
- Requires: Authentication

**GET /api/proxmox/storage?node=pve**
- Get storage pools for node
- Requires: Authentication

### Deployment Endpoints

**POST /api/deployments**
- Create new deployment
- Body: `{template, node, storage, bridge, prefix}`
- Returns: Deployment object

**GET /api/deployments**
- List user's deployments
- Query params: `page, per_page`

**GET /api/deployments/:id**
- Get deployment details
- Requires: Owner or admin

### Results Endpoints

**GET /api/results**
- List lab results
- Query params: `page, per_page`

---

## Deployment

### Production Checklist

- [ ] Change default admin password
- [ ] Generate strong SECRET_KEY
- [ ] Configure HTTPS with SSL certificate
- [ ] Set up firewall rules
- [ ] Configure backup strategy
- [ ] Enable systemd services
- [ ] Set up monitoring
- [ ] Configure log rotation
- [ ] Review security settings
- [ ] Test disaster recovery

### HTTPS Setup

```nginx
# /etc/nginx/sites-available/labmanager
server {
    listen 443 ssl http2;
    server_name labmanager.example.com;

    ssl_certificate /etc/ssl/certs/labmanager.crt;
    ssl_certificate_key /etc/ssl/private/labmanager.key;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Backup Strategy

```bash
# Database backup
pg_dump labmanager > backup_$(date +%Y%m%d).sql

# Configuration backup
tar -czf config_backup_$(date +%Y%m%d).tar.gz .env config.json

# Lab results backup
tar -czf results_backup_$(date +%Y%m%d).tar.gz completedLabs/
```

---

## Security

### Security Features

1. **Authentication**
   - Bcrypt password hashing
   - Session-based authentication
   - Role-based access control

2. **Input Validation**
   - IP address format validation
   - Port number range checking
   - Username format validation
   - Path traversal prevention

3. **Command Injection Prevention**
   - Proper variable quoting
   - Array-based command execution
   - Input sanitization

4. **XSS Prevention**
   - HTML entity encoding
   - Content Security Policy
   - Input sanitization

5. **SQL Injection Prevention**
   - SQLAlchemy ORM
   - Parameterized queries
   - Input validation

### Security Best Practices

- Change default credentials immediately
- Use strong, unique passwords
- Enable HTTPS in production
- Keep software updated
- Monitor logs regularly
- Implement rate limiting
- Use firewall rules
- Regular security audits

---

## Troubleshooting

### Common Issues

**Database connection errors:**
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Check connection
psql -U labmanager -d labmanager -h localhost
```

**Redis connection errors:**
```bash
# Check Redis status
sudo systemctl status redis

# Test connection
redis-cli ping
```

**Proxmox API errors:**
```bash
# Test connection
curl -k https://proxmox-host:8006/api2/json/version
```

**Permission errors:**
```bash
# Fix permissions
chmod +x scripts/*.sh
chmod +x scripts/checklabs/*.sh
chmod +x scripts/createlabs/*.sh
```

### Logs

```bash
# Application logs
tail -f logs/labmanager.log

# Systemd logs
journalctl -u labmanager-api -f
journalctl -u labmanager-celery -f

# Docker logs
docker-compose logs -f api
docker-compose logs -f celery-worker
```

---

## Support

For issues, feature requests, or contributions:
- GitHub: https://github.com/JLATORRE89/labManager
- Email: support@example.com

## License

Copyright © 2025. All rights reserved.
