#!/bin/bash

# Script to verify YUM repository configuration for example.com domain
# Usage: ./check_yum_repo.sh

set -e  # Exit on any error

DOMAIN="example.com"
REPO_DIR="/etc/yum.repos.d"
LOGFILE="../../labresults.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== YUM Repository Verification ===${NC}"
echo "Checking for $DOMAIN repository configuration..."
echo ""

# Function to log results
log_result() {
    echo "$(date): $1" >> "$LOGFILE"
}

# Function to check if /etc/yum.repos.d directory exists
check_repo_directory() {
    echo -e "${BLUE}1. Checking repository directory...${NC}"
    
    if [[ ! -d "$REPO_DIR" ]]; then
        echo -e "   ${RED}✗ FAIL: Repository directory $REPO_DIR does not exist${NC}"
        log_result "FAIL: $REPO_DIR directory missing"
        return 1
    fi
    
    echo -e "   ${GREEN}✓ PASS: Repository directory $REPO_DIR exists${NC}"
    log_result "PASS: Repository directory exists"
    
    # Show directory contents
    echo "   Directory contents:"
    ls -la "$REPO_DIR" | head -10 | while read line; do
        echo "     $line"
    done
    
    local file_count
    file_count=$(ls "$REPO_DIR"/*.repo 2>/dev/null | wc -l)
    echo "   Total .repo files: $file_count"
    
    return 0
}

# Function to search for example.com in repository files
check_domain_in_repos() {
    echo -e "\n${BLUE}2. Searching for $DOMAIN in repository files...${NC}"
    
    local found_files=()
    local found_count=0
    
    # Search for example.com in all .repo files
    for repo_file in "$REPO_DIR"/*.repo; do
        if [[ -f "$repo_file" ]]; then
            if grep -q "$DOMAIN" "$repo_file" 2>/dev/null; then
                found_files+=("$repo_file")
                ((found_count++))
            fi
        fi
    done
    
    if [[ $found_count -gt 0 ]]; then
        echo -e "   ${GREEN}✓ PASS: Found $DOMAIN in $found_count repository file(s)${NC}"
        log_result "PASS: $DOMAIN found in $found_count repo files"
        
        # Show which files contain the domain
        echo "   Files containing $DOMAIN:"
        for file in "${found_files[@]}"; do
            echo "     $(basename "$file")"
        done
        
        return 0
    else
        echo -e "   ${RED}✗ FAIL: $DOMAIN not found in any repository files${NC}"
        log_result "FAIL: $DOMAIN not found in repo files"
        return 1
    fi
}

# Function to analyze repository configuration details
analyze_repo_config() {
    echo -e "\n${BLUE}3. Analyzing repository configuration details...${NC}"
    
    local found_repos=false
    
    # Check each .repo file for example.com
    for repo_file in "$REPO_DIR"/*.repo; do
        if [[ -f "$repo_file" ]] && grep -q "$DOMAIN" "$repo_file" 2>/dev/null; then
            found_repos=true
            echo -e "\n   ${GREEN}Repository file: $(basename "$repo_file")${NC}"
            
            # Show repository sections containing example.com
            echo "   Configuration sections with $DOMAIN:"
            
            # Extract repository sections that contain example.com
            awk -v domain="$DOMAIN" '
                /^\[.*\]/ { 
                    if (section_has_domain) {
                        print "     " section_name
                        for (i in section_lines) print "       " section_lines[i]
                        print ""
                    }
                    section_name = $0
                    delete section_lines
                    section_has_domain = 0
                    line_count = 0
                }
                {
                    section_lines[++line_count] = $0
                    if ($0 ~ domain) section_has_domain = 1
                }
                END {
                    if (section_has_domain) {
                        print "     " section_name
                        for (i in section_lines) print "       " section_lines[i]
                    }
                }
            ' "$repo_file"
            
            # Check for common repository configuration elements
            if grep -q "baseurl.*$DOMAIN" "$repo_file"; then
                echo -e "   ${GREEN}✓ Found baseurl with $DOMAIN${NC}"
                log_result "PASS: baseurl with $DOMAIN found"
            fi
            
            if grep -q "mirrorlist.*$DOMAIN" "$repo_file"; then
                echo -e "   ${GREEN}✓ Found mirrorlist with $DOMAIN${NC}"
                log_result "PASS: mirrorlist with $DOMAIN found"
            fi
            
            if grep -q "enabled.*1" "$repo_file"; then
                echo -e "   ${GREEN}✓ Repository appears to be enabled${NC}"
            elif grep -q "enabled.*0" "$repo_file"; then
                echo -e "   ${YELLOW}⚠ Repository appears to be disabled${NC}"
            fi
        fi
    done
    
    if [[ "$found_repos" == true ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check for DNF command usage evidence or manual creation
check_creation_method() {
    echo -e "\n${BLUE}4. Checking repository creation method...${NC}"
    
    local dnf_evidence=false
    local manual_evidence=false
    
    # Check command history files for dnf config-manager commands
    echo "   Checking for DNF command usage evidence..."
    
    # Check root's bash history
    if [[ -f /root/.bash_history ]]; then
        if grep -q "dnf.*config-manager.*$DOMAIN\|dnf.*config-manager.*example" /root/.bash_history 2>/dev/null; then
            echo -e "   ${GREEN}✓ PASS: DNF config-manager command found in root's history${NC}"
            log_result "PASS: DNF command found in root history"
            dnf_evidence=true
            
            # Show the actual commands used
            echo "   DNF commands found:"
            grep "dnf.*config-manager.*example\|dnf.*config-manager.*$DOMAIN" /root/.bash_history 2>/dev/null | tail -3 | while read cmd; do
                echo "     $cmd"
            done
        fi
    fi
    
    # Check for dnf logs
    local dnf_log_locations=("/var/log/dnf.log" "/var/log/yum.log" "/var/log/dnf.rpm.log")
    
    for log_file in "${dnf_log_locations[@]}"; do
        if [[ -f "$log_file" ]]; then
            # Check recent entries for config-manager or example.com
            if grep "$DOMAIN\|config-manager" "$log_file" >/dev/null 2>&1; then
                echo -e "   ${GREEN}✓ DNF activity found in $log_file${NC}"
                log_result "PASS: DNF activity found in $log_file"
                dnf_evidence=true
                
                # Show recent relevant entries
                echo "   Recent DNF log entries:"
                grep "$DOMAIN\|config-manager" "$log_file" | tail -2 | while read entry; do
                    echo "     $entry"
                done
            fi
        fi
    done
    
    # Check if dnf is available and repo is active
    if command -v dnf >/dev/null 2>&1; then
        if dnf repolist 2>/dev/null | grep -q "$DOMAIN"; then
            echo -e "   ${GREEN}✓ $DOMAIN repository is active in DNF${NC}"
            log_result "PASS: $DOMAIN repo active in DNF"
            dnf_evidence=true
        fi
    fi
    
    # Now check for manual creation evidence
    echo -e "\n   Checking for manual creation evidence..."
    
    # Check command history for manual file creation commands
    if [[ -f /root/.bash_history ]]; then
        # Look for common manual creation commands
        local manual_commands=("vi.*\.repo" "nano.*\.repo" "echo.*repo" "cat.*repo" "touch.*repo" "cp.*repo")
        
        for cmd_pattern in "${manual_commands[@]}"; do
            if grep -q "$cmd_pattern" /root/.bash_history 2>/dev/null; then
                echo -e "   ${GREEN}✓ Manual file creation commands found in history${NC}"
                log_result "PASS: Manual creation commands found"
                manual_evidence=true
                
                echo "   Manual creation commands found:"
                grep -E "(vi|nano|echo|cat|touch|cp).*repo" /root/.bash_history 2>/dev/null | tail -3 | while read cmd; do
                    echo "     $cmd"
                done
                break
            fi
        done
    fi
    
    # Check file timestamps and characteristics for manual creation indicators
    for repo_file in "$REPO_DIR"/*.repo; do
        if [[ -f "$repo_file" ]] && grep -q "$DOMAIN" "$repo_file" 2>/dev/null; then
            echo -e "\n   Analyzing $(basename "$repo_file") characteristics..."
            
            # Check file creation time
            local file_time
            file_time=$(stat -c "%Y" "$repo_file" 2>/dev/null || echo "unknown")
            if [[ "$file_time" != "unknown" ]]; then
                local file_date
                file_date=$(date -d "@$file_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown")
                echo "   File last modified: $file_date"
            fi
            
            # Check file format characteristics
            local sections
            sections=$(grep -c "^\[" "$repo_file" 2>/dev/null || echo "0")
            echo "   Repository sections: $sections"
            
            # Look for typical manual creation patterns
            if grep -q "^# Created manually\|^# Manual\|^# Added by" "$repo_file" 2>/dev/null; then
                echo -e "   ${GREEN}✓ Manual creation comments found${NC}"
                manual_evidence=true
            fi
            
            # Check for DNF-style comments
            if grep -q "# created by dnf config-manager\|# generated by dnf" "$repo_file" 2>/dev/null; then
                echo -e "   ${GREEN}✓ DNF creation markers found${NC}"
                dnf_evidence=true
            fi
            
            # Check file structure for manual vs DNF patterns
            if grep -q "name=.*$DOMAIN\|baseurl=.*$DOMAIN" "$repo_file" 2>/dev/null; then
                if [[ $(wc -l < "$repo_file") -lt 10 ]] && ! grep -q "gpgcheck\|repo_gpgcheck" "$repo_file"; then
                    echo -e "   ${YELLOW}⚠ Simple structure suggests possible manual creation${NC}"
                    manual_evidence=true
                fi
            fi
        fi
    done
    
    # Summary of creation method
    echo -e "\n   ${BLUE}Creation method assessment:${NC}"
    if [[ "$dnf_evidence" == true ]] && [[ "$manual_evidence" == true ]]; then
        echo -e "   ${GREEN}✓ PASS: Evidence of both DNF and manual methods found${NC}"
        log_result "PASS: Both DNF and manual creation evidence found"
    elif [[ "$dnf_evidence" == true ]]; then
        echo -e "   ${GREEN}✓ PASS: DNF creation method detected${NC}"
        log_result "PASS: DNF creation method confirmed"
    elif [[ "$manual_evidence" == true ]]; then
        echo -e "   ${GREEN}✓ PASS: Manual creation method detected${NC}"
        log_result "PASS: Manual creation method confirmed"
    else
        echo -e "   ${YELLOW}⚠ INFO: Creation method unclear (repository exists but method unknown)${NC}"
        log_result "INFO: Repository creation method unclear"
    fi
    
    return 0  # Don't fail based on creation method, just report
}

# Function to show expected creation methods
show_expected_methods() {
    echo -e "\n${BLUE}5. Expected repository creation methods:${NC}"
    
    echo -e "   ${YELLOW}Method 1 - DNF Config Manager (Recommended):${NC}"
    echo "   dnf config-manager --add-repo http://$DOMAIN/repo"
    echo "   dnf config-manager --add-repo https://$DOMAIN/repository"
    echo "   dnf config-manager --add-repo ftp://$DOMAIN/packages"
    
    echo -e "\n   ${YELLOW}Method 2 - Manual Repository File Creation:${NC}"
    echo "   Create file: /etc/yum.repos.d/example-repo.repo"
    echo "   Example content:"
    echo "     [example-repo]"
    echo "     name=Example.com Repository"
    echo "     baseurl=http://$DOMAIN/repo"
    echo "     enabled=1"
    echo "     gpgcheck=0"
    
    echo -e "\n   ${YELLOW}Manual creation commands:${NC}"
    echo "   # Using vi/nano:"
    echo "   vi /etc/yum.repos.d/example.repo"
    echo "   nano /etc/yum.repos.d/example.repo"
    echo ""
    echo "   # Using echo:"
    echo "   echo '[example-repo]' > /etc/yum.repos.d/example.repo"
    echo "   echo 'name=Example Repository' >> /etc/yum.repos.d/example.repo"
    echo "   echo 'baseurl=http://$DOMAIN/repo' >> /etc/yum.repos.d/example.repo"
    echo "   echo 'enabled=1' >> /etc/yum.repos.d/example.repo"
    echo ""
    echo "   # Using cat with heredoc:"
    echo "   cat > /etc/yum.repos.d/example.repo << EOF"
    echo "   [example-repo]"
    echo "   name=Example Repository"
    echo "   baseurl=http://$DOMAIN/repo"
    echo "   enabled=1"
    echo "   gpgcheck=0"
    echo "   EOF"
}

# Function to show additional diagnostics
show_diagnostics() {
    echo -e "\n${BLUE}6. Additional diagnostic information...${NC}"
    
    echo -e "\n${YELLOW}All repository files in $REPO_DIR:${NC}"
    if ls "$REPO_DIR"/*.repo >/dev/null 2>&1; then
        ls -la "$REPO_DIR"/*.repo | while read line; do
            echo "   $line"
        done
    else
        echo "   No .repo files found"
    fi
    
    echo -e "\n${YELLOW}Package manager information:${NC}"
    if command -v dnf >/dev/null 2>&1; then
        echo "   DNF version: $(dnf --version 2>/dev/null | head -1 || echo 'Unable to determine')"
        echo "   DNF available: Yes"
    else
        echo "   DNF available: No"
    fi
    
    if command -v yum >/dev/null 2>&1; then
        echo "   YUM available: Yes"
    else
        echo "   YUM available: No"
    fi
    
    echo -e "\n${YELLOW}Recent repository activity:${NC}"
    if [[ -f /var/log/dnf.log ]]; then
        echo "   Recent DNF log entries:"
        tail -5 /var/log/dnf.log 2>/dev/null | while read line; do
            echo "     $line"
        done
    fi
}

# Main execution
main() {
    local exit_code=0
    
    # Run all checks
    check_repo_directory || exit_code=1
    check_domain_in_repos || exit_code=1
    analyze_repo_config
    check_creation_method
    show_expected_methods
    show_diagnostics
    
    echo ""
    echo "=== FINAL RESULTS ==="
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}🎉 VERIFICATION PASSED! Repository for $DOMAIN found.${NC}"
        log_result "YUM REPO VERIFICATION PASSED: $DOMAIN repository configured"
    else
        echo -e "${RED}❌ VERIFICATION FAILED! Repository for $DOMAIN not properly configured.${NC}"
        log_result "YUM REPO VERIFICATION FAILED: $DOMAIN repository missing"
        echo ""
        echo -e "${YELLOW}To fix:${NC}"
        echo "1. DNF method: dnf config-manager --add-repo http://$DOMAIN/repo"
        echo "2. Manual method: Create .repo file in $REPO_DIR with $DOMAIN baseurl"
        echo "   Example: echo '[example-repo]' > $REPO_DIR/example.repo"
        echo "            echo 'baseurl=http://$DOMAIN/repo' >> $REPO_DIR/example.repo"
        echo "3. Ensure repository is enabled"
    fi
    
    echo ""
    echo "Verification log saved to: $LOGFILE"
    echo -e "${BLUE}YUM repository verification completed.${NC}"
    
    return $exit_code
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}Note: Some checks may require root privileges for complete verification${NC}"
    echo "For full verification, run: sudo ./check_yum_repo.sh"
    echo ""
fi

# Run main function
main "$@"