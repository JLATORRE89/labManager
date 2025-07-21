# CentOS Stream Lab Deployer & Orchestration System for Proxmox

A comprehensive web interface and command-line system for deploying, executing, and grading CentOS Stream lab environments in Proxmox for Linux system administration training.

## Features

### Lab Deployment (Web Interface)
- Simple web interface for deploying CentOS Stream lab VMs
- API token-based authentication for secure Proxmox access
- Multiple lab templates (Base and Extended)
- Remote console access to lab VMs
- Real-time deployment progress and logs

### Lab Orchestration & Grading (Command Line)
- **Automated lab execution** on deployed VMs via SSH
- **Pass/fail grading system** with improvement tracking
- **Batch processing** for multiple students/VMs
- **Comprehensive reporting** (Text, JSON, HTML formats)
- **VM configuration management** for easy reuse
- **Progress tracking** showing student learning over multiple attempts

## Prerequisites

- Proxmox VE 7.0 or higher
- API token with appropriate permissions
- [CentOS Stream 9 ISO](https://www.centos.org/stream9/) uploaded to Proxmox storage
- SSH access to deployed lab VMs
- Python 3.6+ for grading system
- `sshpass` package for password-based SSH authentication (optional)

For detailed CentOS Stream documentation, see the [official documentation](https://docs.centos.org/).

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/JLATORRE89/labManager.git
   cd labManager
   ```

2. Make orchestration scripts executable:
   ```bash
   chmod +x run_vm_labs.sh vm_config.sh
   chmod +x scripts/createlabs/*.sh scripts/checklabs/*.sh
   ```

3. Install dependencies (if using password authentication):
   ```bash
   # Ubuntu/Debian
   sudo apt-get install sshpass
   
   # RHEL/CentOS/Oracle Linux
   sudo dnf install sshpass
   ```

4. Deploy web interface (optional):
   ```bash
   # Using Python's built-in server for testing
   python3 -m http.server 8080
   ```

5. Access the web interface:
   ```
   http://localhost:8080
   ```

## Quick Start Guide

### 1. Deploy Lab VMs (Web Interface)
1. Open the web interface and connect to your Proxmox API
2. Configure lab settings (node, storage, networking)
3. Deploy your lab environment (Base or Extended)
4. Wait for VMs to be created and note their IP addresses

### 2. Run Labs on VMs (Command Line)
```bash
# One-time execution with SSH key
./run_vm_labs.sh --vm-ip 192.168.1.100 --vm-user root --ssh-key ~/.ssh/id_rsa --student-name "John Doe"

# Or with password authentication  
./run_vm_labs.sh --vm-ip 192.168.1.100 --vm-user root --vm-password "password" --student-name "Jane Smith"
```

### 3. View Results
```bash
# Check the completedLabs directory for generated reports
ls completedLabs/
# john_doe_20250721_143022_report.txt
# john_doe_20250721_143022_report.html
# john_doe_20250721_143022_grades.json
```

## Lab Orchestration System

### VM Configuration Management
Save frequently used VM configurations for easy reuse:

```bash
# Create a new VM configuration interactively
./vm_config.sh create student-vm-01

# List all saved configurations
./vm_config.sh list

# Run labs using saved configuration
./vm_config.sh run student-vm-01

# Run with additional options
./vm_config.sh run student-vm-01 --skip-create --verbose
```

### Batch Processing
Process multiple VMs automatically:

1. Create a batch file `students.txt`:
   ```
   run student1-vm --student-name "John Doe"
   run student2-vm --student-name "Jane Smith"
   run student3-vm --student-name "Bob Wilson"
   ```

2. Execute batch processing:
   ```bash
   ./vm_config.sh batch students.txt
   ```

### Command Line Options

#### Main Orchestrator (`run_vm_labs.sh`)
```bash
# Required
--vm-ip <IP>            # IP address of target VM
--vm-user <user>        # SSH username

# Authentication (choose one)
--vm-password <pwd>     # SSH password
--ssh-key <path>        # SSH private key path

# Optional
--vm-port <port>        # SSH port (default: 22)
--student-name <name>   # Student identifier
--timeout <seconds>     # Script timeout (default: 300)
--skip-create          # Skip lab creation phase
--skip-check           # Skip lab checking phase  
--skip-grade           # Skip grading phase
--verbose              # Enable verbose output
```

### Grading System

The system uses a **pass/fail grading approach** with improvement tracking:

- **Pass/Fail per Task**: Each task either passes or fails completely
- **Improvement Tracking**: Shows learning progress over multiple attempts
- **Retry Success Recognition**: Celebrates tasks that succeeded after initial failure
- **Overall Lab Status**: Lab passes only if ALL tasks pass

#### Sample Grade Report
```
================================================================================
LAB GRADING REPORT - PASS/FAIL WITH IMPROVEMENT TRACKING
================================================================================

OVERALL SUMMARY
----------------------------------------
Total Labs: 3
Labs Passed: 2
Labs Failed: 1
Overall Status: FAIL

LAB RESULTS
----------------------------------------
✓ User Management        : PASS (5/5 tasks, 8 total attempts)
✓ NFS Configuration      : PASS (3/3 tasks, 3 total attempts)
✗ Package Management     : FAIL (2/3 tasks, 7 total attempts)

IMPROVEMENT ANALYSIS
----------------------------------------
First-try successes: 6
Retry successes: 4
💪 Improvement shown: 4 tasks succeeded after retry!
```

#### Manual Grading
```bash
# Generate text report
python3 grade_labs.py

# Generate JSON for automation
python3 grade_labs.py --output-format json

# Generate HTML report
python3 grade_labs.py --output-format html --output-file report.html
```

## Lab Scripts Structure

```
scripts/
├── createlabs/          # Lab setup scripts
│   ├── generate_sally_files.sh
│   ├── generate_nfs_setup.sh
│   └── generate_yum_repos.sh
└── checklabs/           # Lab verification scripts
    ├── usercheck.sh
    ├── check_nfs_share.sh
    └── check_yum_repo.sh
```

### Adding New Labs

1. **Create Lab Generator**: Add setup script to `scripts/createlabs/`
2. **Create Lab Checker**: Add verification script to `scripts/checklabs/`
3. **Follow Logging Format**:
   ```bash
   log_result "PASS: Task completed successfully"
   log_result "FAIL: Task failed - reason"
   ```

See `integration_guide.md` for detailed lab development guidelines.

## Web Interface Configuration

### Using the Config File

Create `config.json` for automated deployments:

```json
{
  "proxmoxHost": "https://your-proxmox-server:8006",
  "tokenId": "user@pam!token_name", 
  "tokenSecret": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "defaultNode": "pve",
  "defaultStorage": "local-lvm",
  "defaultBridge": "vmbr0",
  "defaultPrefix": "centos9-",
  "defaultIsoLocation": "local:iso/centos-stream-9.iso",
  "autoConnect": true,
  "hideConnectionForm": false
}
```

### Proxmox API Token Setup

1. Navigate to Datacenter → Permissions → API Tokens
2. Create new token with required permissions:
   - VM.Allocate
   - VM.Config.*
   - Datastore.AllocateSpace
   - Datastore.Audit

## Lab Templates

### Base Lab (Server + Client)
- 1 [CentOS Stream 9](https://www.centos.org/stream9/) Server VM (2 CPU, 2GB RAM, 20GB disk)
- 1 CentOS Stream 9 Client VM (1 CPU, 1GB RAM, 10GB disk)
- Basic networking configuration

### Extended Lab (Server + 2 Clients)  
- 1 CentOS Stream 9 Server VM (2 CPU, 2GB RAM, 20GB disk)
- 2 CentOS Stream 9 Client VMs (1 CPU, 1GB RAM, 10GB disk each)
- Extended networking configuration

For complete installation and configuration guidance, refer to the [CentOS Stream Documentation](https://docs.centos.org/).

## Output Structure

```
labManager/
├── completedLabs/                    # Generated reports
│   ├── john_doe_20250721_143022_report.txt
│   ├── john_doe_20250721_143022_grades.json
│   ├── john_doe_20250721_143022_report.html
│   └── john_doe_20250721_143022_summary.txt
├── vm_configs/                       # Saved VM configurations
│   ├── student-vm-01.conf
│   └── lab-group-1.conf
├── scripts/                          # Lab scripts
├── labresults.log                    # Consolidated lab results
└── integration_guide.md              # Developer guide
```

## Deploying to Oracle Cloud Infrastructure

1. Create compute instance (VM.Standard.E4.Flex recommended)
2. Install web server:
   ```bash
   sudo dnf install nginx -y
   sudo systemctl enable nginx --now
   
   # Open firewall
   sudo firewall-cmd --permanent --add-service={http,https}
   sudo firewall-cmd --reload
   ```

3. Deploy application:
   ```bash
   sudo mkdir -p /var/www/html/centos-lab-deployer
   sudo cp -r * /var/www/html/centos-lab-deployer/
   sudo chown -R nginx:nginx /var/www/html/centos-lab-deployer
   ```

## Integration with LMS

The JSON output format enables integration with Learning Management Systems:

```bash
# Export grades in JSON format
python3 grade_labs.py --output-format json --output-file grades.json

# JSON structure includes:
# - overall_status (PASS/FAIL)
# - individual lab results
# - improvement metrics
# - task-level details with timestamps
```

## Troubleshooting

### Web Interface Issues
- Verify Proxmox host accessibility
- Check API token permissions
- Review firewall settings

### VM Orchestration Issues
- **SSH Connection Failed**: Check VM IP, SSH service, and credentials
- **Script Timeouts**: Increase timeout value or check VM performance
- **Permission Denied**: Ensure user has sudo privileges
- **Missing Reports**: Check `labresults.log` exists and is accessible

### Common Solutions
```bash
# Test SSH connectivity
ssh user@vm-ip 'echo "Connection test"'

# Check VM SSH service
ssh user@vm-ip 'systemctl status sshd'

# Verify sudo access
ssh user@vm-ip 'sudo whoami'

# Debug script execution
./run_vm_labs.sh --vm-ip X.X.X.X --vm-user root --ssh-key ~/.ssh/id_rsa --verbose
```

## Performance Recommendations

- **Concurrent Processing**: Process multiple VMs in parallel using batch files
- **Resource Monitoring**: Monitor Proxmox resource usage during batch operations  
- **Network Optimization**: Use local network segments for faster file transfers
- **Storage Performance**: Use SSD storage for improved VM performance

## Security Considerations

- Store VM configurations with restricted permissions (600)
- Use SSH keys instead of passwords when possible
- Regularly rotate API tokens
- Monitor access logs for unauthorized usage
- Keep lab VMs on isolated network segments

## Contributing

Contributions are welcome! Areas for contribution:
- Additional lab scripts for different Linux system administration objectives
- Integration with other virtualization platforms
- Enhanced reporting features
- Performance optimizations

Please see `integration_guide.md` for development guidelines.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Based on Linux system administration best practices
- Proxmox API documentation and community
- [CentOS Stream project](https://www.centos.org/stream9/) and [official documentation](https://docs.centos.org/)