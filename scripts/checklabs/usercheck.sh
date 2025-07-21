#!/bin/bash

# Script to verify user file collection - checks if find command was executed properly
# Usage: ./usercheck.sh

set -e  # Exit on any error

USERNAME="sally"
HOME_DIR="/home/$USERNAME"
COLLECTION_DIR="/root/sally"
LOGFILE="../../labresults.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== User File Collection Verification ===${NC}"
echo "Checking file collection status for user: $USERNAME"
echo ""

# Function to log results
log_result() {
    echo "$(date): $1" >> "$LOGFILE"
}

# Function to check if user exists
check_user_exists() {
    echo -e "${BLUE}1. Checking if user '$USERNAME' exists...${NC}"
    if id "$USERNAME" &>/dev/null; then
        echo -e "   ${GREEN}✓ PASS: User '$USERNAME' exists${NC}"
        log_result "PASS: User $USERNAME exists"
        
        # Show user details
        echo "   User details: $(id $USERNAME)"
        return 0
    else
        echo -e "   ${RED}✗ FAIL: User '$USERNAME' does not exist${NC}"
        log_result "FAIL: User $USERNAME does not exist"
        return 1
    fi
}

# Function to check source files in home directory
check_source_files() {
    echo -e "\n${BLUE}2. Checking source files in $HOME_DIR...${NC}"
    
    if [[ ! -d "$HOME_DIR" ]]; then
        echo -e "   ${RED}✗ FAIL: Home directory $HOME_DIR does not exist${NC}"
        log_result "FAIL: Home directory missing"
        return 1
    fi
    
    # Count files owned by sally in home directory
    local file_count
    file_count=$(find "$HOME_DIR" -user "$USERNAME" -type f 2>/dev/null | wc -l)
    
    if [[ $file_count -gt 0 ]]; then
        echo -e "   ${GREEN}✓ PASS: Found $file_count files owned by '$USERNAME' in home directory${NC}"
        log_result "PASS: Found $file_count source files"
        
        # List the files
        echo "   Files found:"
        find "$HOME_DIR" -user "$USERNAME" -type f 2>/dev/null | head -10 | while read file; do
            echo "     - $file"
        done
        if [[ $file_count -gt 10 ]]; then
            echo "     ... and $((file_count - 10)) more files"
        fi
        return 0
    else
        echo -e "   ${RED}✗ FAIL: No files owned by '$USERNAME' found in home directory${NC}"
        log_result "FAIL: No source files found"
        return 1
    fi
}

# Function to check collection directory
check_collection_dir() {
    echo -e "\n${BLUE}3. Checking collection directory $COLLECTION_DIR...${NC}"
    
    if [[ ! -d "$COLLECTION_DIR" ]]; then
        echo -e "   ${RED}✗ FAIL: Collection directory $COLLECTION_DIR does not exist${NC}"
        log_result "FAIL: Collection directory missing"
        return 1
    fi
    
    # Count files in collection directory
    local collected_count
    collected_count=$(find "$COLLECTION_DIR" -type f 2>/dev/null | wc -l)
    
    if [[ $collected_count -gt 0 ]]; then
        echo -e "   ${GREEN}✓ PASS: Found $collected_count files in collection directory${NC}"
        log_result "PASS: Found $collected_count collected files"
        
        # List collected files
        echo "   Collected files:"
        ls -la "$COLLECTION_DIR" | head -15
        if [[ $collected_count -gt 12 ]]; then  # accounting for . and .. entries
            echo "     ... and more files"
        fi
        return 0
    else
        echo -e "   ${RED}✗ FAIL: No files found in collection directory${NC}"
        log_result "FAIL: No files collected"
        return 1
    fi
}

# Function to verify the find command was likely executed
verify_find_command() {
    echo -e "\n${BLUE}4. Verifying find command execution...${NC}"
    
    # Get file counts
    local source_count
    local collected_count
    source_count=$(find /home -user "$USERNAME" -type f 2>/dev/null | wc -l)
    collected_count=$(find "$COLLECTION_DIR" -type f 2>/dev/null | wc -l)
    
    echo "   Source files owned by '$USERNAME' in /home: $source_count"
    echo "   Files collected in $COLLECTION_DIR: $collected_count"
    
    if [[ $collected_count -gt 0 ]] && [[ $source_count -gt 0 ]]; then
        if [[ $collected_count -ge $source_count ]]; then
            echo -e "   ${GREEN}✓ PASS: Find command appears to have been executed successfully${NC}"
            echo -e "   ${GREEN}✓ All or more files were collected than expected${NC}"
            log_result "PASS: Find command executed successfully"
            return 0
        else
            echo -e "   ${YELLOW}⚠ PARTIAL: Some files collected but count is lower than expected${NC}"
            echo -e "   ${YELLOW}  This might be normal due to directory structures${NC}"
            log_result "PARTIAL: Partial collection detected"
            return 0
        fi
    else
        echo -e "   ${RED}✗ FAIL: Find command does not appear to have been executed${NC}"
        log_result "FAIL: Find command not executed"
        return 1
    fi
}

# Function to show the expected command
show_expected_command() {
    echo -e "\n${BLUE}5. Expected command verification:${NC}"
    echo -e "   ${YELLOW}Expected command:${NC}"
    echo "   find /home -user $USERNAME -exec cp {} $COLLECTION_DIR/ \\; 2>/dev/null"
    echo ""
    echo -e "   ${YELLOW}Alternative acceptable commands:${NC}"
    echo "   find /home -user $USERNAME -exec cp {} $COLLECTION_DIR/ \\;"
    echo "   find /home -user $USERNAME -exec cp {} $COLLECTION_DIR \\;"
}

# Function to check command history (if available)
check_command_history() {
    echo -e "\n${BLUE}6. Checking command history...${NC}"
    
    # Check root's bash history for the command
    if [[ -f /root/.bash_history ]]; then
        if grep -q "find.*-user.*$USERNAME.*exec.*cp" /root/.bash_history 2>/dev/null; then
            echo -e "   ${GREEN}✓ PASS: Find command found in root's command history${NC}"
            log_result "PASS: Command found in history"
            
            # Show the actual command used
            echo "   Command(s) found:"
            grep "find.*-user.*$USERNAME.*exec.*cp" /root/.bash_history 2>/dev/null | tail -3 | while read cmd; do
                echo "     $cmd"
            done
        else
            echo -e "   ${YELLOW}⚠ INFO: Find command not found in root's bash history${NC}"
            echo "   (This is normal if history is disabled or cleared)"
        fi
    else
        echo -e "   ${YELLOW}⚠ INFO: No bash history file found for root${NC}"
    fi
}

# Main execution
main() {
    local exit_code=0
    
    # Run all checks
    check_user_exists || exit_code=1
    check_source_files || exit_code=1
    check_collection_dir || exit_code=1
    verify_find_command || exit_code=1
    show_expected_command
    check_command_history
    
    echo ""
    echo "=== FINAL RESULTS ==="
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}🎉 VERIFICATION PASSED! All checks completed successfully.${NC}"
        log_result "VERIFICATION PASSED: All checks successful"
    else
        echo -e "${RED}❌ VERIFICATION FAILED! Some checks did not pass.${NC}"
        log_result "VERIFICATION FAILED: Some checks failed"
        echo ""
        echo -e "${YELLOW}To fix issues:${NC}"
        echo "1. Ensure user 'sally' exists: sudo useradd -m sally"
        echo "2. Create some files owned by sally in /home/sally"
        echo "3. Run: find /home -user sally -exec cp {} /root/sally/ \\;"
    fi
    
    echo ""
    echo "Verification log saved to: $LOGFILE"
    echo -e "${BLUE}Verification completed.${NC}"
    
    return $exit_code
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script should be run as root for complete verification${NC}"
    echo "Run: sudo ./usercheck.sh"
    echo ""
    echo "Continuing with limited checks..."
    echo ""
fi

# Run main function
main "$@"