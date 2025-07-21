#!/bin/bash

# Script to verify NFS usershare configuration
# Usage: ./check_nfs_share.sh

set -e  # Exit on any error

NFS_SHARE_NAME="usershare"
MOUNT_POINT="/home/shares"
USER_NAME="eric"
USER_HOME="$MOUNT_POINT/$USER_NAME"
LOGFILE="../../labresults.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== NFS Share Verification ===${NC}"
echo "Checking usershare NFS configuration..."
echo ""

# Function to log results
log_result() {
    echo "$(date): $1" >> "$LOGFILE"
}

# Function to check /etc/fstab for usershare entry
check_fstab() {
    echo -e "${BLUE}1. Checking /etc/fstab for usershare entry...${NC}"
    
    if [[ ! -f /etc/fstab ]]; then
        echo -e "   ${RED}✗ FAIL: /etc/fstab file not found${NC}"
        log_result "FAIL: /etc/fstab not found"
        return 1
    fi
    
    # Look for usershare in fstab (various possible formats)
    if grep -q "usershare" /etc/fstab 2>/dev/null; then
        echo -e "   ${GREEN}✓ PASS: usershare found in /etc/fstab${NC}"
        log_result "PASS: usershare found in fstab"
        
        # Show the matching line(s)
        echo "   Matching entries:"
        grep "usershare" /etc/fstab | while read line; do
            echo "     $line"
        done
        
        # Check if it's pointing to /home/shares
        if grep "usershare.*$MOUNT_POINT" /etc/fstab >/dev/null 2>&1; then
            echo -e "   ${GREEN}✓ BONUS: Entry correctly points to $MOUNT_POINT${NC}"
            log_result "PASS: usershare correctly configured for $MOUNT_POINT"
        else
            echo -e "   ${YELLOW}⚠ INFO: usershare found but mount point may differ${NC}"
            log_result "INFO: usershare mount point differs"
        fi
        
        return 0
    else
        echo -e "   ${RED}✗ FAIL: usershare not found in /etc/fstab${NC}"
        log_result "FAIL: usershare not in fstab"
        
        # Show what IS in fstab for debugging
        echo "   Current /etc/fstab entries:"
        cat /etc/fstab | grep -v "^#" | grep -v "^$" | head -5 | while read line; do
            echo "     $line"
        done
        
        return 1
    fi
}

# Function to check if usershare is mounted at /home/shares
check_mount() {
    echo -e "\n${BLUE}2. Checking if usershare is mounted at $MOUNT_POINT...${NC}"
    
    # Check if mount point directory exists
    if [[ ! -d "$MOUNT_POINT" ]]; then
        echo -e "   ${RED}✗ FAIL: Mount point directory $MOUNT_POINT does not exist${NC}"
        log_result "FAIL: Mount point $MOUNT_POINT does not exist"
        return 1
    fi
    
    # Check if something is mounted at the mount point
    if mount | grep -q "$MOUNT_POINT" 2>/dev/null; then
        echo -e "   ${GREEN}✓ PASS: Something is mounted at $MOUNT_POINT${NC}"
        log_result "PASS: Mount detected at $MOUNT_POINT"
        
        # Show what's mounted there
        echo "   Mount details:"
        mount | grep "$MOUNT_POINT" | while read line; do
            echo "     $line"
        done
        
        # Check if it's specifically usershare
        if mount | grep "$MOUNT_POINT" | grep -q "usershare" 2>/dev/null; then
            echo -e "   ${GREEN}✓ BONUS: usershare is specifically mounted at $MOUNT_POINT${NC}"
            log_result "PASS: usershare mounted at $MOUNT_POINT"
        else
            echo -e "   ${YELLOW}⚠ INFO: Mount found but may not be usershare${NC}"
            log_result "INFO: Non-usershare mount at $MOUNT_POINT"
        fi
        
        return 0
    else
        echo -e "   ${RED}✗ FAIL: Nothing mounted at $MOUNT_POINT${NC}"
        log_result "FAIL: Nothing mounted at $MOUNT_POINT"
        
        # Show current mounts for debugging
        echo "   Current NFS/network mounts:"
        mount | grep -E "(nfs|cifs|smbfs)" | head -3 | while read line; do
            echo "     $line"
        done
        
        return 1
    fi
}

# Function to check if user eric has home directory in /home/shares
check_user_home() {
    echo -e "\n${BLUE}3. Checking if user $USER_NAME has home directory in $MOUNT_POINT...${NC}"
    
    # First check if user exists
    if ! id "$USER_NAME" &>/dev/null; then
        echo -e "   ${RED}✗ FAIL: User '$USER_NAME' does not exist${NC}"
        log_result "FAIL: User $USER_NAME does not exist"
        return 1
    fi
    
    echo -e "   ${GREEN}✓ User '$USER_NAME' exists${NC}"
    
    # Get user's home directory from passwd
    local actual_home
    actual_home=$(getent passwd "$USER_NAME" | cut -d: -f6)
    
    echo "   User $USER_NAME home directory: $actual_home"
    echo "   Expected location: $USER_HOME"
    
    # Check if home directory is inside /home/shares
    if [[ "$actual_home" == "$USER_HOME" ]]; then
        echo -e "   ${GREEN}✓ PASS: User $USER_NAME home directory is correctly set to $USER_HOME${NC}"
        log_result "PASS: User $USER_NAME home in $MOUNT_POINT"
    elif [[ "$actual_home" == $MOUNT_POINT/* ]]; then
        echo -e "   ${GREEN}✓ PASS: User $USER_NAME home directory is inside $MOUNT_POINT${NC}"
        echo "   (Located at: $actual_home)"
        log_result "PASS: User $USER_NAME home inside $MOUNT_POINT"
    else
        echo -e "   ${RED}✗ FAIL: User $USER_NAME home directory is NOT inside $MOUNT_POINT${NC}"
        log_result "FAIL: User $USER_NAME home not in $MOUNT_POINT"
        return 1
    fi
    
    # Check if the directory actually exists
    if [[ -d "$actual_home" ]]; then
        echo -e "   ${GREEN}✓ PASS: Home directory physically exists${NC}"
        log_result "PASS: $USER_NAME home directory exists"
        
        # Show directory contents
        echo "   Directory contents (first few items):"
        ls -la "$actual_home" 2>/dev/null | head -5 | while read line; do
            echo "     $line"
        done
        
        return 0
    else
        echo -e "   ${RED}✗ FAIL: Home directory $actual_home does not exist${NC}"
        log_result "FAIL: $USER_NAME home directory does not exist"
        return 1
    fi
}

# Function to show additional diagnostic info
show_diagnostics() {
    echo -e "\n${BLUE}4. Additional diagnostic information...${NC}"
    
    echo -e "\n${YELLOW}NFS Services Status:${NC}"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl is-active nfs-client 2>/dev/null || echo "   nfs-client service not running"
        systemctl is-active rpcbind 2>/dev/null || echo "   rpcbind service not running"
    fi
    
    echo -e "\n${YELLOW}Mount Point Information:${NC}"
    if [[ -d "$MOUNT_POINT" ]]; then
        echo "   $MOUNT_POINT directory exists"
        echo "   Permissions: $(ls -ld "$MOUNT_POINT" 2>/dev/null | cut -d' ' -f1)"
        echo "   Owner: $(ls -ld "$MOUNT_POINT" 2>/dev/null | cut -d' ' -f3-4)"
    else
        echo "   $MOUNT_POINT directory does not exist"
    fi
    
    echo -e "\n${YELLOW}Network File System Mounts:${NC}"
    mount | grep -E "(nfs|cifs)" | head -5 | while read line; do
        echo "   $line"
    done
    
    if ! mount | grep -E "(nfs|cifs)" >/dev/null; then
        echo "   No NFS or CIFS mounts detected"
    fi
}

# Main execution
main() {
    local exit_code=0
    
    # Run all checks
    check_fstab || exit_code=1
    check_mount || exit_code=1
    check_user_home || exit_code=1
    show_diagnostics
    
    echo ""
    echo "=== FINAL RESULTS ==="
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}🎉 VERIFICATION PASSED! All NFS share requirements met.${NC}"
        log_result "NFS VERIFICATION PASSED: All checks successful"
    else
        echo -e "${RED}❌ VERIFICATION FAILED! Some requirements not met.${NC}"
        log_result "NFS VERIFICATION FAILED: Some checks failed"
        echo ""
        echo -e "${YELLOW}Common fixes:${NC}"
        echo "1. Add usershare to /etc/fstab: echo 'server:/path/usershare $MOUNT_POINT nfs defaults 0 0' >> /etc/fstab"
        echo "2. Create mount point: mkdir -p $MOUNT_POINT"
        echo "3. Mount the share: mount $MOUNT_POINT"
        echo "4. Create user with correct home: useradd -m -d $USER_HOME $USER_NAME"
    fi
    
    echo ""
    echo "Verification log saved to: $LOGFILE"
    echo -e "${BLUE}NFS verification completed.${NC}"
    
    return $exit_code
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}Note: Some checks may require root privileges for complete verification${NC}"
    echo "For full verification, run: sudo ./check_nfs_share.sh"
    echo ""
fi

# Run main function
main "$@"