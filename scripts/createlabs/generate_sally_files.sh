#!/bin/bash

# Script to generate files for user 'sally' and collect them
# Creates user if it doesn't exist
# Usage: ./generate_sally_files.sh

set -e  # Exit on any error

USERNAME="sally"
HOME_DIR="/home/$USERNAME"
COLLECTION_DIR="/root/sally"

echo "=== Sally File Generator ==="

# Function to create user if not exists
create_user() {
    echo "Checking if user '$USERNAME' exists..."
    
    if ! id "$USERNAME" &>/dev/null; then
        echo "User '$USERNAME' does not exist. Creating user..."
        
        # Create user with home directory and bash shell
        useradd -m -s /bin/bash "$USERNAME"
        
        # Set a temporary password (user should change it)
        echo "$USERNAME:temp123" | chpasswd
        
        # Force password change on first login
        chage -d 0 "$USERNAME"
        
        echo "✓ User '$USERNAME' created successfully"
        echo "✓ Home directory: $HOME_DIR"
        echo "✓ Temporary password: temp123 (must be changed on first login)"
        
    else
        echo "✓ User '$USERNAME' already exists"
    fi
}

# Function to generate sample files
generate_files() {
    echo "Generating files for user: $USERNAME"
    
    # Ensure home directory exists and set ownership
    mkdir -p "$HOME_DIR"
    chown "$USERNAME:$USERNAME" "$HOME_DIR"
    
    # Generate various file types in home directory
    sudo -u "$USERNAME" bash << EOF
        # Create some text files
        echo "Sally's personal notes" > "$HOME_DIR/notes.txt"
        echo "Important documents for Sally" > "$HOME_DIR/documents.txt"
        
        # Create a config directory with files
        mkdir -p "$HOME_DIR/.config/myapp"
        echo "app_setting=enabled" > "$HOME_DIR/.config/myapp/config.conf"
        
        # Create a documents directory
        mkdir -p "$HOME_DIR/Documents"
        echo "Project plan for Sally" > "$HOME_DIR/Documents/project.txt"
        echo "Meeting notes from today" > "$HOME_DIR/Documents/meeting_notes.txt"
        
        # Create some hidden files
        echo "Sally's bash history" > "$HOME_DIR/.bash_history"
        echo "export PATH=\$PATH:/usr/local/bin" > "$HOME_DIR/.bashrc"
        
        # Create a downloads directory with a sample file
        mkdir -p "$HOME_DIR/Downloads"
        echo "Sample download content" > "$HOME_DIR/Downloads/sample.log"
        
        # Create a script file
        mkdir -p "$HOME_DIR/scripts"
        cat > "$HOME_DIR/scripts/backup.sh" << 'SCRIPT'
#!/bin/bash
echo "Sally's backup script"
date > /tmp/sally_backup.log
SCRIPT
        chmod +x "$HOME_DIR/scripts/backup.sh"
EOF
    
    echo "Files generated successfully in $HOME_DIR"
    echo "File count: $(find "$HOME_DIR" -type f | wc -l)"
}

# Function to collect files using the find command
collect_files() {
    echo "Creating collection directory: $COLLECTION_DIR"
    mkdir -p "$COLLECTION_DIR"
    
    echo "Collecting files owned by $USERNAME..."
    
    # Your original command with a small fix (added 2>/dev/null to suppress permission errors)
    find /home -user "$USERNAME" -exec cp {} "$COLLECTION_DIR/" \; 2>/dev/null || true
    
    echo "Files collected in $COLLECTION_DIR"
    echo "Collected file count: $(find "$COLLECTION_DIR" -type f | wc -l)"
    
    # List collected files
    echo "Collected files:"
    ls -la "$COLLECTION_DIR"
}

# Main execution
main() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root (use sudo)"
        echo "Example: sudo ./generate_sally_files.sh"
        exit 1
    fi
    
    echo "Starting file generation for user: $USERNAME"
    
    create_user
    generate_files
    collect_files
    
    echo ""
    echo "=== Process completed successfully ==="
    echo "Files generated in: $HOME_DIR"
    echo "Files collected in: $COLLECTION_DIR"
}

# Run main function
main "$@"