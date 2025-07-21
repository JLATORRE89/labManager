#!/bin/bash

# VM Lab Orchestration Script for Proxmox
# Runs lab creation, checking, and grading against remote VMs
# Usage: ./run_vm_labs.sh --vm-ip <IP> --vm-user <user> [options]

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREATELABS_DIR="$SCRIPT_DIR/scripts/createlabs"
CHECKLABS_DIR="$SCRIPT_DIR/scripts/checklabs"
COMPLETED_DIR="$SCRIPT_DIR/completedLabs"
LOG_FILE="$SCRIPT_DIR/labresults.log"
GRADER_SCRIPT="$SCRIPT_DIR/grade_labs.py"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default values
VM_IP=""
VM_USER="root"
VM_PASSWORD=""
SSH_KEY=""
VM_PORT="22"
TIMEOUT="300"
STUDENT_NAME="student"
RUN_CREATE=true
RUN_CHECK=true
RUN_GRADE=true
VERBOSE=false

# Usage function
usage() {
    cat << EOF
VM Lab Orchestration Script

Usage: $0 --vm-ip <IP> --vm-user <user> [OPTIONS]

Required Arguments:
    --vm-ip <IP>        IP address of the target VM
    --vm-user <user>    SSH username for VM connection

Authentication (choose one):
    --vm-password <pwd> Password for SSH connection
    --ssh-key <path>    Path to SSH private key file

Optional Arguments:
    --vm-port <port>    SSH port (default: 22)
    --student-name <name> Student identifier (default: student)
    --timeout <seconds>  Script timeout in seconds (default: 300)
    --skip-create       Skip lab creation phase
    --skip-check        Skip lab checking phase
    --skip-grade        Skip grading phase
    --verbose           Enable verbose output
    --help             Show this help message

Examples:
    # Using password authentication
    $0 --vm-ip 192.168.1.100 --vm-user root --vm-password mypassword

    # Using SSH key authentication
    $0 --vm-ip 192.168.1.100 --vm-user root --ssh-key ~/.ssh/id_rsa

    # Custom student name and skip creation
    $0 --vm-ip 192.168.1.100 --vm-user root --ssh-key ~/.ssh/id_rsa \\
       --student-name john_doe --skip-create

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --vm-ip)
                VM_IP="$2"
                shift 2
                ;;
            --vm-user)
                VM_USER="$2"
                shift 2
                ;;
            --vm-password)
                VM_PASSWORD="$2"
                shift 2
                ;;
            --ssh-key)
                SSH_KEY="$2"
                shift 2
                ;;
            --vm-port)
                VM_PORT="$2"
                shift 2
                ;;
            --student-name)
                STUDENT_NAME="$2"
                shift 2
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --skip-create)
                RUN_CREATE=false
                shift
                ;;
            --skip-check)
                RUN_CHECK=false
                shift
                ;;
            --skip-grade)
                RUN_GRADE=false
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Validate required arguments
    if [[ -z "$VM_IP" ]]; then
        echo -e "${RED}Error: --vm-ip is required${NC}"
        usage
        exit 1
    fi

    if [[ -z "$VM_PASSWORD" && -z "$SSH_KEY" ]]; then
        echo -e "${RED}Error: Either --vm-password or --ssh-key is required${NC}"
        usage
        exit 1
    fi
}

# Setup SSH connection parameters
setup_ssh() {
    SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -p $VM_PORT"
    
    if [[ -n "$SSH_KEY" ]]; then
        if [[ ! -f "$SSH_KEY" ]]; then
            echo -e "${RED}Error: SSH key file not found: $SSH_KEY${NC}"
            exit 1
        fi
        SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
        SSH_CMD="ssh $SSH_OPTS $VM_USER@$VM_IP"
        SCP_CMD="scp $SSH_OPTS"
    else
        # Using sshpass for password authentication
        if ! command -v sshpass >/dev/null 2>&1; then
            echo -e "${RED}Error: sshpass is required for password authentication${NC}"
            echo "Install with: sudo apt-get install sshpass (Ubuntu/Debian)"
            echo "             sudo yum install sshpass (RHEL/CentOS)"
            exit 1
        fi
        SSH_CMD="sshpass -p '$VM_PASSWORD' ssh $SSH_OPTS $VM_USER@$VM_IP"
        SCP_CMD="sshpass -p '$VM_PASSWORD' scp $SSH_OPTS"
    fi
}

# Test VM connectivity
test_connectivity() {
    echo -e "${BLUE}Testing VM connectivity...${NC}"
    
    if eval "$SSH_CMD 'echo \"Connection successful\"'" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ VM connection established${NC}"
        
        # Get VM info
        OS_INFO=$(eval "$SSH_CMD 'cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d \"'\"' || echo 'Unknown OS'")
        echo -e "${CYAN}VM OS: $OS_INFO${NC}"
    else
        echo -e "${RED}✗ Failed to connect to VM${NC}"
        exit 1
    fi
}

# Copy script to VM and execute
run_remote_script() {
    local script_path="$1"
    local script_name=$(basename "$script_path")
    local phase="$2"
    
    if [[ ! -f "$script_path" ]]; then
        echo -e "${RED}✗ Script not found: $script_path${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Running $script_name...${NC}"
    
    # Copy script to VM
    eval "$SCP_CMD '$script_path' '$VM_USER@$VM_IP:/tmp/$script_name'" || {
        echo -e "${RED}✗ Failed to copy $script_name to VM${NC}"
        return 1
    }
    
    # Make script executable and run
    local remote_cmd="chmod +x /tmp/$script_name && cd /tmp && timeout $TIMEOUT sudo /tmp/$script_name"
    
    if [[ "$VERBOSE" == true ]]; then
        eval "$SSH_CMD '$remote_cmd'" || {
            echo -e "${RED}✗ Failed to execute $script_name${NC}"
            return 1
        }
    else
        eval "$SSH_CMD '$remote_cmd'" >/dev/null 2>&1 || {
            echo -e "${RED}✗ Failed to execute $script_name${NC}"
            return 1
        }
    fi
    
    echo -e "${GREEN}✓ $script_name completed${NC}"
    return 0
}

# Download log file from VM
download_logs() {
    echo -e "${BLUE}Downloading lab results...${NC}"
    
    # Try to download the log file from various possible locations
    local log_locations=("/tmp/labresults.log" "../../labresults.log" "/root/labresults.log" "/var/log/labresults.log")
    local downloaded=false
    
    for remote_log in "${log_locations[@]}"; do
        if eval "$SSH_CMD 'test -f $remote_log'" 2>/dev/null; then
            echo -e "${CYAN}Found log at: $remote_log${NC}"
            
            # Create temporary local file
            local temp_log="/tmp/vm_labresults_$(date +%s).log"
            
            if eval "$SCP_CMD '$VM_USER@$VM_IP:$remote_log' '$temp_log'"; then
                # Append to main log file with student identifier
                echo "# VM Lab Results for $STUDENT_NAME - $(date)" >> "$LOG_FILE"
                echo "# VM: $VM_IP ($OS_INFO)" >> "$LOG_FILE"
                cat "$temp_log" >> "$LOG_FILE"
                echo "" >> "$LOG_FILE"
                
                rm -f "$temp_log"
                downloaded=true
                echo -e "${GREEN}✓ Lab results downloaded${NC}"
                break
            fi
        fi
    done
    
    if [[ "$downloaded" != true ]]; then
        echo -e "${YELLOW}⚠ No lab results log found on VM${NC}"
    fi
}

# Run lab creation scripts
run_create_phase() {
    echo -e "\n${BLUE}=== LAB CREATION PHASE ===${NC}"
    
    if [[ ! -d "$CREATELABS_DIR" ]]; then
        echo -e "${RED}Error: Create labs directory not found: $CREATELABS_DIR${NC}"
        return 1
    fi
    
    local script_count=0
    local success_count=0
    
    for script in "$CREATELABS_DIR"/*.sh; do
        if [[ -f "$script" ]]; then
            ((script_count++))
            if run_remote_script "$script" "create"; then
                ((success_count++))
            fi
        fi
    done
    
    echo -e "\n${CYAN}Create Phase Summary: $success_count/$script_count scripts succeeded${NC}"
    
    if [[ $success_count -eq 0 ]]; then
        echo -e "${RED}No creation scripts succeeded${NC}"
        return 1
    fi
    
    return 0
}

# Run lab checking scripts
run_check_phase() {
    echo -e "\n${BLUE}=== LAB CHECKING PHASE ===${NC}"
    
    if [[ ! -d "$CHECKLABS_DIR" ]]; then
        echo -e "${RED}Error: Check labs directory not found: $CHECKLABS_DIR${NC}"
        return 1
    fi
    
    local script_count=0
    local success_count=0
    
    for script in "$CHECKLABS_DIR"/*.sh; do
        if [[ -f "$script" ]]; then
            ((script_count++))
            if run_remote_script "$script" "check"; then
                ((success_count++))
            fi
        fi
    done
    
    echo -e "\n${CYAN}Check Phase Summary: $success_count/$script_count scripts succeeded${NC}"
    download_logs
    
    return 0
}

# Run grading and generate reports
run_grade_phase() {
    echo -e "\n${BLUE}=== GRADING PHASE ===${NC}"
    
    if [[ ! -f "$GRADER_SCRIPT" ]]; then
        echo -e "${RED}Error: Grader script not found: $GRADER_SCRIPT${NC}"
        return 1
    fi
    
    # Create completed labs directory
    mkdir -p "$COMPLETED_DIR"
    
    # Generate timestamp for unique filenames
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local report_prefix="${STUDENT_NAME}_${timestamp}"
    
    # Generate reports
    echo -e "${YELLOW}Generating grade reports...${NC}"
    
    # Text report
    python3 "$GRADER_SCRIPT" --output-file "$COMPLETED_DIR/${report_prefix}_report.txt"
    echo -e "${GREEN}✓ Text report: ${report_prefix}_report.txt${NC}"
    
    # JSON report
    python3 "$GRADER_SCRIPT" --output-format json --output-file "$COMPLETED_DIR/${report_prefix}_grades.json"
    echo -e "${GREEN}✓ JSON report: ${report_prefix}_grades.json${NC}"
    
    # HTML report
    python3 "$GRADER_SCRIPT" --output-format html --output-file "$COMPLETED_DIR/${report_prefix}_report.html"
    echo -e "${GREEN}✓ HTML report: ${report_prefix}_report.html${NC}"
    
    # Create summary file
    cat > "$COMPLETED_DIR/${report_prefix}_summary.txt" << EOF
Lab Execution Summary for $STUDENT_NAME
========================================
Execution Date: $(date)
VM IP: $VM_IP
VM OS: $OS_INFO
Student: $STUDENT_NAME

Files Generated:
- ${report_prefix}_report.txt  (Detailed text report)
- ${report_prefix}_grades.json (JSON data for automation)
- ${report_prefix}_report.html (Web-viewable report)
- ${report_prefix}_summary.txt (This summary file)

Lab Results Location: $LOG_FILE
EOF
    
    echo -e "${GREEN}✓ Summary: ${report_prefix}_summary.txt${NC}"
    echo -e "\n${CYAN}All reports saved to: $COMPLETED_DIR${NC}"
    
    return 0
}

# Main execution function
main() {
    echo -e "${BLUE}VM Lab Orchestration System${NC}"
    echo -e "${CYAN}Student: $STUDENT_NAME${NC}"
    echo -e "${CYAN}Target VM: $VM_USER@$VM_IP:$VM_PORT${NC}"
    echo ""
    
    # Setup and test connection
    setup_ssh
    test_connectivity
    
    local overall_success=true
    
    # Run creation phase
    if [[ "$RUN_CREATE" == true ]]; then
        if ! run_create_phase; then
            overall_success=false
        fi
    else
        echo -e "${YELLOW}Skipping lab creation phase${NC}"
    fi
    
    # Run checking phase
    if [[ "$RUN_CHECK" == true ]]; then
        if ! run_check_phase; then
            overall_success=false
        fi
    else
        echo -e "${YELLOW}Skipping lab checking phase${NC}"
    fi
    
    # Run grading phase
    if [[ "$RUN_GRADE" == true ]]; then
        if ! run_grade_phase; then
            overall_success=false
        fi
    else
        echo -e "${YELLOW}Skipping grading phase${NC}"
    fi
    
    # Final summary
    echo -e "\n${BLUE}=== EXECUTION COMPLETE ===${NC}"
    
    if [[ "$overall_success" == true ]]; then
        echo -e "${GREEN}🎉 Lab orchestration completed successfully!${NC}"
        echo -e "${CYAN}Check the completedLabs directory for all reports${NC}"
    else
        echo -e "${YELLOW}⚠ Lab orchestration completed with some issues${NC}"
        echo -e "${CYAN}Check the logs and reports for details${NC}"
    fi
    
    return 0
}

# Cleanup function for signal handling
cleanup() {
    echo -e "\n${YELLOW}Cleaning up...${NC}"
    # Remove any temporary files
    rm -f /tmp/vm_labresults_*.log
    exit 1
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Parse arguments and run main function
parse_args "$@"
main