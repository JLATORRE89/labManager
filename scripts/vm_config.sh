#!/bin/bash

# VM Configuration Helper
# Creates and manages VM configurations for lab execution
# Usage: ./vm_config.sh [create|list|run] [config_name]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/vm_configs"
ORCHESTRATOR="$SCRIPT_DIR/run_vm_labs.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

create_config() {
    local config_name="$1"
    if [[ -z "$config_name" ]]; then
        echo -e "${RED}Error: Config name required${NC}"
        echo "Usage: $0 create <config_name>"
        exit 1
    fi
    
    local config_file="$CONFIG_DIR/${config_name}.conf"
    
    if [[ -f "$config_file" ]]; then
        echo -e "${YELLOW}Config already exists: $config_name${NC}"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    echo -e "${BLUE}Creating VM configuration: $config_name${NC}"
    echo ""
    
    # Get VM details interactively
    read -p "VM IP address: " vm_ip
    read -p "SSH username [root]: " vm_user
    vm_user=${vm_user:-root}
    read -p "SSH port [22]: " vm_port
    vm_port=${vm_port:-22}
    
    echo ""
    echo "Authentication method:"
    echo "1) SSH Key (recommended)"
    echo "2) Password"
    read -p "Choose (1/2): " auth_method
    
    if [[ "$auth_method" == "1" ]]; then
        read -p "SSH private key path [~/.ssh/id_rsa]: " ssh_key
        ssh_key=${ssh_key:-~/.ssh/id_rsa}
        # Expand tilde
        ssh_key="${ssh_key/#\~/$HOME}"
        
        if [[ ! -f "$ssh_key" ]]; then
            echo -e "${YELLOW}Warning: SSH key file not found: $ssh_key${NC}"
        fi
        
        # Create config file
        cat > "$config_file" << EOF
# VM Configuration: $config_name
# Created: $(date)

VM_IP="$vm_ip"
VM_USER="$vm_user"
VM_PORT="$vm_port"
SSH_KEY="$ssh_key"
EOF
    else
        read -s -p "VM password: " vm_password
        echo
        
        # Create config file
        cat > "$config_file" << EOF
# VM Configuration: $config_name  
# Created: $(date)

VM_IP="$vm_ip"
VM_USER="$vm_user"
VM_PORT="$vm_port"
VM_PASSWORD="$vm_password"
EOF
    fi
    
    read -p "Default student name [student]: " student_name
    student_name=${student_name:-student}
    
    read -p "Script timeout in seconds [300]: " timeout
    timeout=${timeout:-300}
    
    # Append additional settings
    cat >> "$config_file" << EOF
STUDENT_NAME="$student_name"
TIMEOUT="$timeout"
EOF
    
    chmod 600 "$config_file"  # Restrict permissions for security
    
    echo -e "${GREEN}✓ Configuration saved: $config_file${NC}"
    echo -e "${CYAN}Run with: $0 run $config_name${NC}"
}

list_configs() {
    echo -e "${BLUE}Available VM Configurations:${NC}"
    echo ""
    
    if [[ ! -d "$CONFIG_DIR" ]] || [[ -z "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]]; then
        echo -e "${YELLOW}No configurations found${NC}"
        echo -e "${CYAN}Create one with: $0 create <name>${NC}"
        return
    fi
    
    for config in "$CONFIG_DIR"/*.conf; do
        if [[ -f "$config" ]]; then
            local name=$(basename "$config" .conf)
            echo -e "${GREEN}$name${NC}"
            
            # Extract key info from config
            local vm_ip=$(grep "^VM_IP=" "$config" | cut -d'"' -f2)
            local vm_user=$(grep "^VM_USER=" "$config" | cut -d'"' -f2)
            local student=$(grep "^STUDENT_NAME=" "$config" | cut -d'"' -f2)
            
            echo -e "  ${CYAN}VM: $vm_user@$vm_ip${NC}"
            echo -e "  ${CYAN}Student: $student${NC}"
            echo ""
        fi
    done
}

run_with_config() {
    local config_name="$1"
    if [[ -z "$config_name" ]]; then
        echo -e "${RED}Error: Config name required${NC}"
        echo "Usage: $0 run <config_name>"
        list_configs
        exit 1
    fi
    
    local config_file="$CONFIG_DIR/${config_name}.conf"
    
    if [[ ! -f "$config_file" ]]; then
        echo -e "${RED}Error: Configuration not found: $config_name${NC}"
        list_configs
        exit 1
    fi
    
    echo -e "${BLUE}Loading configuration: $config_name${NC}"
    
    # Source the configuration
    source "$config_file"
    
    # Build orchestrator command
    local cmd="$ORCHESTRATOR --vm-ip \"$VM_IP\" --vm-user \"$VM_USER\""
    
    if [[ -n "$VM_PORT" ]]; then
        cmd="$cmd --vm-port \"$VM_PORT\""
    fi
    
    if [[ -n "$SSH_KEY" ]]; then
        cmd="$cmd --ssh-key \"$SSH_KEY\""
    elif [[ -n "$VM_PASSWORD" ]]; then
        cmd="$cmd --vm-password \"$VM_PASSWORD\""
    fi
    
    if [[ -n "$STUDENT_NAME" ]]; then
        cmd="$cmd --student-name \"$STUDENT_NAME\""
    fi
    
    if [[ -n "$TIMEOUT" ]]; then
        cmd="$cmd --timeout \"$TIMEOUT\""
    fi
    
    # Add any additional arguments passed to this script
    shift  # Remove config_name
    cmd="$cmd $*"
    
    echo -e "${CYAN}Executing: $cmd${NC}"
    echo ""
    
    # Execute the orchestrator
    eval "$cmd"
}

# Batch processing function
run_batch() {
    local batch_file="$1"
    if [[ -z "$batch_file" ]]; then
        echo -e "${RED}Error: Batch file required${NC}"
        echo "Usage: $0 batch <batch_file>"
        exit 1
    fi
    
    if [[ ! -f "$batch_file" ]]; then
        echo -e "${RED}Error: Batch file not found: $batch_file${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Running batch processing from: $batch_file${NC}"
    
    local line_num=0
    local success_count=0
    local total_count=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        ((total_count++))
        
        echo -e "\n${CYAN}=== Batch Job $total_count (Line $line_num) ===${NC}"
        echo -e "${YELLOW}Command: $line${NC}"
        
        # Execute the line as a command
        if eval "$0 $line"; then
            ((success_count++))
            echo -e "${GREEN}✓ Batch job $total_count completed successfully${NC}"
        else
            echo -e "${RED}✗ Batch job $total_count failed${NC}"
        fi
    done < "$batch_file"
    
    echo -e "\n${BLUE}=== Batch Processing Complete ===${NC}"
    echo -e "${CYAN}Results: $success_count/$total_count jobs succeeded${NC}"
}

# Usage function
usage() {
    cat << EOF
VM Configuration Helper

Usage: $0 <command> [arguments]

Commands:
    create <name>           Create a new VM configuration
    list                    List all available configurations  
    run <name> [options]    Run labs using a saved configuration
    batch <file>            Run multiple configurations from a file
    help                    Show this help message

Examples:
    # Create a new configuration
    $0 create lab-vm-01
    
    # List all configurations
    $0 list
    
    # Run labs with a saved configuration
    $0 run lab-vm-01
    
    # Run with additional options
    $0 run lab-vm-01 --skip-create --verbose
    
    # Batch process multiple VMs
    $0 batch student_vms.txt

Batch File Format:
    run student1-vm --student-name "John Doe"  
    run student2-vm --student-name "Jane Smith"
    run lab-group-1 --skip-create

EOF
}

# Main execution
case "$1" in
    create)
        create_config "$2"
        ;;
    list)
        list_configs
        ;;
    run)
        run_with_config "$2" "${@:3}"
        ;;
    batch)
        run_batch "$2"
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo -e "${RED}Error: Unknown command: $1${NC}"
        echo ""
        usage
        exit 1
        ;;
esac