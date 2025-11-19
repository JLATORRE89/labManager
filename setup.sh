#!/bin/bash

# Lab Manager Installation Script
# Automated setup for development and production environments

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Lab Manager Installation Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}Error: Do not run this script as root${NC}"
    exit 1
fi

# Detect OS
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
else
    echo -e "${RED}Error: Cannot detect operating system${NC}"
    exit 1
fi

echo -e "${GREEN}Detected OS: $PRETTY_NAME${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install system dependencies
install_dependencies() {
    echo -e "${YELLOW}Installing system dependencies...${NC}"

    case $OS in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y \
                python3 \
                python3-pip \
                python3-venv \
                redis-server \
                sshpass \
                git \
                curl \
                || { echo -e "${RED}Failed to install dependencies${NC}"; exit 1; }
            ;;
        rhel|centos|rocky|almalinux)
            sudo dnf install -y \
                python3 \
                python3-pip \
                redis \
                sshpass \
                git \
                curl \
                || { echo -e "${RED}Failed to install dependencies${NC}"; exit 1; }
            ;;
        *)
            echo -e "${RED}Unsupported operating system: $OS${NC}"
            exit 1
            ;;
    esac

    echo -e "${GREEN}✓ System dependencies installed${NC}"
}

# Setup Python virtual environment
setup_virtualenv() {
    echo -e "${YELLOW}Setting up Python virtual environment...${NC}"

    if [[ ! -d venv ]]; then
        python3 -m venv venv
    fi

    source venv/bin/activate

    pip install --upgrade pip
    pip install -r requirements.txt

    echo -e "${GREEN}✓ Python virtual environment ready${NC}"
}

# Generate secret key
generate_secret_key() {
    python3 -c "import secrets; print(secrets.token_hex(32))"
}

# Setup environment file
setup_env_file() {
    echo -e "${YELLOW}Setting up environment configuration...${NC}"

    if [[ -f .env ]]; then
        echo -e "${YELLOW}Warning: .env file already exists${NC}"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi

    # Copy example and customize
    cp .env.example .env

    # Generate secret key
    SECRET_KEY=$(generate_secret_key)
    sed -i "s/SECRET_KEY=.*/SECRET_KEY=$SECRET_KEY/" .env

    echo -e "${GREEN}✓ Environment file created: .env${NC}"
    echo -e "${YELLOW}⚠  Please edit .env with your Proxmox credentials${NC}"
}

# Initialize database
init_database() {
    echo -e "${YELLOW}Initializing database...${NC}"

    source venv/bin/activate
    python3 << EOF
from app import app, init_database
init_database()
print("Database initialized successfully")
EOF

    echo -e "${GREEN}✓ Database initialized${NC}"
}

# Start Redis
start_redis() {
    echo -e "${YELLOW}Starting Redis server...${NC}"

    case $OS in
        ubuntu|debian)
            sudo systemctl enable redis-server
            sudo systemctl start redis-server
            ;;
        rhel|centos|rocky|almalinux)
            sudo systemctl enable redis
            sudo systemctl start redis
            ;;
    esac

    echo -e "${GREEN}✓ Redis server started${NC}"
}

# Create systemd services
create_systemd_services() {
    echo -e "${YELLOW}Creating systemd services...${NC}"

    CURRENT_DIR=$(pwd)
    USER=$(whoami)

    # Flask API service
    sudo tee /etc/systemd/system/labmanager-api.service > /dev/null << EOF
[Unit]
Description=Lab Manager API Server
After=network.target redis.service

[Service]
Type=notify
User=$USER
WorkingDirectory=$CURRENT_DIR
Environment="PATH=$CURRENT_DIR/venv/bin"
EnvironmentFile=$CURRENT_DIR/.env
ExecStart=$CURRENT_DIR/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 4 --worker-class gevent --timeout 120 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Celery worker service
    sudo tee /etc/systemd/system/labmanager-celery.service > /dev/null << EOF
[Unit]
Description=Lab Manager Celery Worker
After=network.target redis.service

[Service]
Type=forking
User=$USER
WorkingDirectory=$CURRENT_DIR
Environment="PATH=$CURRENT_DIR/venv/bin"
EnvironmentFile=$CURRENT_DIR/.env
ExecStart=$CURRENT_DIR/venv/bin/celery -A tasks worker --loglevel=info --concurrency=4 --detach
ExecStop=$CURRENT_DIR/venv/bin/celery -A tasks control shutdown
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload

    echo -e "${GREEN}✓ Systemd services created${NC}"
}

# Setup firewall
setup_firewall() {
    echo -e "${YELLOW}Configuring firewall...${NC}"

    if command_exists firewall-cmd; then
        sudo firewall-cmd --permanent --add-port=5000/tcp
        sudo firewall-cmd --reload
        echo -e "${GREEN}✓ Firewall configured (firewalld)${NC}"
    elif command_exists ufw; then
        sudo ufw allow 5000/tcp
        echo -e "${GREEN}✓ Firewall configured (ufw)${NC}"
    else
        echo -e "${YELLOW}⚠  No firewall detected, skipping${NC}"
    fi
}

# Main installation
main() {
    echo "This script will install Lab Manager and its dependencies."
    echo ""
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi

    install_dependencies
    setup_virtualenv
    setup_env_file
    init_database
    start_redis
    create_systemd_services
    setup_firewall

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Installation Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Edit .env file with your Proxmox credentials"
    echo "2. Start services:"
    echo "   sudo systemctl start labmanager-api"
    echo "   sudo systemctl start labmanager-celery"
    echo "3. Enable services to start on boot:"
    echo "   sudo systemctl enable labmanager-api"
    echo "   sudo systemctl enable labmanager-celery"
    echo "4. Access the web interface at http://$(hostname -I | awk '{print $1}'):5000"
    echo "5. Default login: admin / admin (change this!)"
    echo ""
}

# Run main function
main "$@"
