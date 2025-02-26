# RHCSA9 Lab Deployer for Proxmox

A web interface for easily deploying Red Hat Certified System Administrator (RHCSA9) lab environments in Proxmox.

## Features

- Simple web interface for deploying RHCSA9 lab VMs
- API token-based authentication for secure Proxmox access
- Multiple lab templates (Base and Extended)
- Remote console access to lab VMs
- Real-time deployment progress and logs

## Prerequisites

- Proxmox VE 7.0 or higher
- API token with appropriate permissions
- RHEL9 or CentOS Stream 9 ISO uploaded to Proxmox storage

## Installation

1. Clone this repository:
   ```
   git clone https://github.com/JLATORRE89/labManager.git
   cd labManager
   ```

2. Deploy to your web server or run locally:
   ```
   # Using Python's built-in server for testing
   python3 -m http.server 8080
   ```

3. Access the web interface:
   ```
   http://localhost:8080
   ```

### Deploying to Oracle Cloud Infrastructure

To deploy on Oracle Cloud or other cloud compute services:

1. Create a compute instance (e.g., VM.Standard.E4.Flex)
2. Install a web server:
   ```bash
   # For Oracle Linux / RHEL based systems
   sudo dnf install nginx -y
   sudo systemctl enable nginx
   sudo systemctl start nginx
   
   # Open firewall ports
   sudo firewall-cmd --permanent --add-service=http
   sudo firewall-cmd --permanent --add-service=https
   sudo firewall-cmd --reload
   ```

3. Deploy the application:
   ```bash
   sudo mkdir -p /var/www/html/rhcsa-deployer
   sudo cp -r * /var/www/html/rhcsa-deployer/
   ```

4. Create and configure your `config.json` file:
   ```bash
   sudo nano /var/www/html/rhcsa-deployer/config.json
   # Add your Proxmox connection details
   ```

5. Set proper permissions:
   ```bash
   sudo chown -R nginx:nginx /var/www/html/rhcsa-deployer
   ```

6. Access the application via your instance's public IP
   ```
   http://your-instance-ip
   ```

## Configuration

### Using the Config File

The application can be configured to use a config file instead of requiring manual input. This is useful for:
- Running in headless environments (like Oracle Cloud)
- Deploying in a controlled setting where credentials shouldn't be entered manually
- Setting up kiosk or lab environments

To use automatic configuration:
1. Create or edit the `config.json` file in the root directory
2. Add your Proxmox API connection details and preferences
3. Set `autoConnect` to `true` to connect automatically on page load

Example `config.json`:
```json
{
  "proxmoxHost": "https://your-proxmox-server:8006",
  "tokenId": "user@pam!token_name",
  "tokenSecret": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "defaultNode": "pve",
  "defaultStorage": "local-lvm",
  "defaultBridge": "vmbr0",
  "defaultPrefix": "rhcsa9-",
  "defaultIsoLocation": "local:iso/rhel9.iso",
  "autoConnect": true,
  "hideConnectionForm": false
}
```

### Create a Proxmox API Token

1. Log in to your Proxmox web interface
2. Navigate to Datacenter → Permissions → API Tokens
3. Click "Add" to create a new token
4. Select a user, enter a token ID, and decide whether to set Privilege Separation
5. Save the Token ID and Secret (only shown once)

The token requires the following permissions:
- VM.Allocate
- VM.Config.*
- Datastore.AllocateSpace
- Datastore.Audit

### Configure the Lab Deployer

1. Open the web interface
2. Enter your Proxmox API connection details:
   - Proxmox Host URL
   - API Token ID
   - API Token Secret
3. Connect to the Proxmox API
4. Configure your lab settings
5. Deploy your lab environment

## Lab Templates

### Base Lab (Server + Client)
- 1 RHEL9 Server VM
- 1 RHEL9 Client VM
- Basic networking

### Extended Lab (Server + 2 Clients)
- 1 RHEL9 Server VM
- 2 RHEL9 Client VMs
- Extended networking configuration

## VM Specifications

### Server VM
- CPU: 2 cores
- RAM: 2GB
- Disk: 20GB
- Network: vmbr0

### Client VM
- CPU: 1 core
- RAM: 1GB
- Disk: 10GB
- Network: vmbr0

## Usage

See the included user manual for detailed usage instructions.

## Troubleshooting

### Connection Issues
- Verify your Proxmox host is accessible
- Ensure your API token has correct permissions
- Check firewall settings that might block API connections

### Deployment Problems
- Check storage availability on Proxmox
- Verify ISO location is correct
- Review deployment logs for specific errors

## Contributing

Contributions are welcome! Please feel free to submit pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Based on the [RHCSA9 lab setup scripts](https://github.com/aggressiveHiker/rhcsa9)