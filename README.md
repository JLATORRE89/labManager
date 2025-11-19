# Lab Manager - RHCSA9 Training Platform

A production-ready platform for automated deployment and management of Linux system administration training labs on Proxmox VE.

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![License](https://img.shields.io/badge/license-Proprietary-red.svg)
![Python](https://img.shields.io/badge/python-3.9+-green.svg)
![Flask](https://img.shields.io/badge/flask-3.0-lightgrey.svg)

---

## 🚀 Features

- **Automated VM Deployment**: Deploy CentOS Stream 9/RHEL 9 lab environments via web interface
- **Lab Execution & Grading**: SSH-based remote execution with automated verification and comprehensive grading
- **Multi-User Support**: Role-based access control with admin and user roles
- **RESTful API**: Full-featured API for integration and automation
- **Background Processing**: Async task execution with Celery for scalability
- **Database Tracking**: Persistent storage of deployments, results, and user activity
- **Modern Web UI**: Responsive interface with real-time updates
- **Comprehensive Security**: Input validation, XSS prevention, SQL injection protection

---

## 📋 Quick Start

### Prerequisites

- Linux server (Ubuntu 20.04+, RHEL 8+, CentOS Stream 9+)
- Python 3.9+
- Redis server
- PostgreSQL 12+ or SQLite
- Proxmox VE 7.0+

### Installation

```bash
# Clone repository
git clone https://github.com/JLATORRE89/labManager.git
cd labManager

# Run automated setup
chmod +x setup.sh
./setup.sh

# Edit configuration
nano .env

# Start services
sudo systemctl start labmanager-api
sudo systemctl start labmanager-celery
```

### Docker Deployment (Recommended for Production)

```bash
# Configure environment
cp .env.example .env
# Edit .env with your Proxmox credentials

# Start all services
docker-compose up -d

# Access at http://your-server:5000
```

### Default Credentials

- **Username:** admin
- **Password:** admin

**⚠️ Change these immediately in production!**

---

## 🏗️ Architecture

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │ HTTPS
       ▼
┌─────────────┐      ┌────────────┐
│    Nginx    │─────▶│ Flask API  │
└─────────────┘      └─────┬──────┘
                           │
                 ┌─────────┼─────────┐
                 │         │         │
                 ▼         ▼         ▼
         ┌──────────┐ ┌────────┐ ┌────────┐
         │PostgreSQL│ │ Redis  │ │Proxmox │
         └──────────┘ └────┬───┘ └────────┘
                           ▼
                    ┌──────────────┐
                    │Celery Worker │
                    └──────────────┘
```

**Technology Stack:**
- **Frontend:** HTML5, CSS3, JavaScript (Vanilla)
- **Backend:** Flask 3.0, SQLAlchemy, Celery
- **Database:** PostgreSQL / SQLite
- **Message Queue:** Redis
- **Virtualization:** Proxmox VE
- **Deployment:** Docker, Systemd, Nginx

---

## 📖 Documentation

- **[Full MVP Documentation](MVP_DOCUMENTATION.md)** - Comprehensive guide
- **[Code Review Summary](CODE_REVIEW_SUMMARY.md)** - Security audit details
- **[Integration Guide](integration_guide.md)** - Add new labs
- **[User Manual](user-manual.html)** - End-user guide

---

## 🔒 Security

This project includes comprehensive security measures:

- ✅ **Authentication:** Bcrypt password hashing, session management
- ✅ **Input Validation:** IP addresses, ports, usernames, file paths
- ✅ **Injection Prevention:** SQL, command, and XSS protection
- ✅ **Secure Credentials:** Environment variables, SSHPASS handling
- ✅ **Path Traversal Protection:** Realpath validation
- ✅ **CORS Protection:** Configurable origins

See [CODE_REVIEW_SUMMARY.md](CODE_REVIEW_SUMMARY.md) for detailed security audit.

---

## 🎯 Use Cases

1. **Educational Institutions** - Linux administration training
2. **Certification Prep** - RHCSA/RHCE exam preparation
3. **Corporate Training** - IT skills development
4. **Self-Study** - Individual learning with automated feedback
5. **Lab Automation** - Automated testing and validation

---

## 📊 Project Structure

```
labManager/
├── app.py                    # Flask API server
├── tasks.py                  # Celery background tasks
├── api-client.js             # Frontend API client
├── index.html                # Main application page
├── login.html                # Login page
├── requirements.txt          # Python dependencies
├── docker-compose.yml        # Docker orchestration
├── Dockerfile                # Container image
├── setup.sh                  # Installation script
├── .env.example              # Environment template
├── scripts/
│   ├── run_vm_labs.sh       # Main orchestration script
│   ├── vm_config.sh         # VM configuration helper
│   ├── createlabs/          # Lab creation scripts
│   └── checklabs/           # Lab verification scripts
├── grade_labs.py            # Grading system
└── completedLabs/           # Generated reports
```

---

## 🚦 Usage

### Web Interface

1. Access `http://your-server:5000`
2. Login with credentials
3. Connect to Proxmox
4. Deploy lab environment
5. Execute labs on VMs
6. View results and reports

### Command Line

```bash
# Create VM configuration
./scripts/vm_config.sh create lab-vm-01

# Run labs
./scripts/run_vm_labs.sh --vm-ip 192.168.1.100 \
  --vm-user root --ssh-key ~/.ssh/id_rsa \
  --student-name john_doe

# Generate grading report
python3 grade_labs.py --output-format html \
  --output-file report.html
```

### API

```bash
# Login
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}' \
  -c cookies.txt

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

## 🔧 Configuration

### Environment Variables

Key configurations in `.env`:

```bash
# Application
SECRET_KEY=your-secret-key
FLASK_ENV=production

# Database
DATABASE_URL=postgresql://user:pass@localhost/labmanager

# Proxmox
PROXMOX_HOST=https://proxmox.example.com:8006
PROXMOX_TOKEN_NAME=labmanager
PROXMOX_TOKEN_VALUE=your-token-value

# Admin
ADMIN_USERNAME=admin
ADMIN_PASSWORD=secure-password
```

See `.env.example` for full configuration options.

---

## 📈 Monitoring

### Health Check

```bash
curl http://localhost:5000/api/health
```

### Logs

```bash
# Application logs
tail -f logs/labmanager.log

# Systemd logs
journalctl -u labmanager-api -f
journalctl -u labmanager-celery -f

# Docker logs
docker-compose logs -f
```

---

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

---

## 🐛 Troubleshooting

### Common Issues

**Can't connect to Proxmox:**
- Verify Proxmox host is accessible
- Check API token is valid
- Ensure firewall allows connection

**Database errors:**
- Check PostgreSQL/Redis are running
- Verify DATABASE_URL in .env
- Run database initialization

**Permission denied:**
- Ensure scripts are executable: `chmod +x scripts/*.sh`
- Check file ownership and permissions

See [MVP_DOCUMENTATION.md](MVP_DOCUMENTATION.md#troubleshooting) for detailed troubleshooting.

---

## 📝 License

Copyright © 2025. All rights reserved.

---

## 🙏 Acknowledgments

- Proxmox VE team for virtualization platform
- Flask team for excellent web framework
- Red Hat for CentOS Stream and RHEL

---

## 📞 Support

- **GitHub Issues:** [Report bugs or request features](https://github.com/JLATORRE89/labManager/issues)
- **Email:** support@example.com
- **Documentation:** [Full docs](MVP_DOCUMENTATION.md)

---

**Made with ❤️ for Linux education**
