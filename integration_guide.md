# Lab Integration Guide

## Quick Reference for Adding New Lab Scripts

### Script Naming Convention
- **Generator Scripts**: `generate_[task]_[subject].sh` (e.g., `generate_sally_files.sh`)
- **Checker Scripts**: `[subject]check.sh` (e.g., `usercheck.sh`, `nfscheck.sh`)
- **Log Output**: `../../labresults.log` (relative to script location)

### Standard Script Structure

#### 1. Generator Script Template
```bash
#!/bin/bash
# Script to generate [TASK DESCRIPTION]
# Usage: ./generate_[name].sh

set -e  # Exit on any error

# Variables
TARGET="[subject]"
TARGET_DIR="/path/to/target"
LOGFILE="../../labresults.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== [Task] Generator ===${NC}"

# Functions
create_target() {
    # Implementation
}

generate_content() {
    # Implementation  
}

verify_results() {
    # Implementation
}

# Main execution
main() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root (use sudo)"
        exit 1
    fi
    
    create_target
    generate_content
    verify_results
    
    echo "=== Process completed successfully ==="
}

main "$@"
```

#### 2. Checker Script Template
```bash
#!/bin/bash
# Script to verify [TASK DESCRIPTION]
# Usage: ./[subject]check.sh

set -e
LOGFILE="../../labresults.log"

# Colors (same as above)

echo -e "${BLUE}=== [Task] Verification ===${NC}"

# Logging function
log_result() {
    echo "$(date): $1" >> "$LOGFILE"
}

# Check functions
check_requirement_1() {
    echo -e "${BLUE}1. Checking [requirement]...${NC}"
    
    if [[ condition ]]; then
        echo -e "   ${GREEN}✓ PASS: [success message]${NC}"
        log_result "PASS: [requirement] met"
        return 0
    else
        echo -e "   ${RED}✗ FAIL: [failure message]${NC}"
        log_result "FAIL: [requirement] not met"
        return 1
    fi
}

# Main execution with exit code tracking
main() {
    local exit_code=0
    
    check_requirement_1 || exit_code=1
    check_requirement_2 || exit_code=1
    check_requirement_3 || exit_code=1
    
    echo ""
    echo "=== FINAL RESULTS ==="
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}🎉 VERIFICATION PASSED!${NC}"
        log_result "VERIFICATION PASSED: All checks successful"
    else
        echo -e "${RED}❌ VERIFICATION FAILED!${NC}"
        log_result "VERIFICATION FAILED: Some checks failed"
    fi
    
    echo "Verification log saved to: $LOGFILE"
    return $exit_code
}

main "$@"
```

### Common Lab Types & Examples

#### User Management Labs
- **Generator**: Create users, home directories, files
- **Checker**: Verify user exists, home directory, file ownership
- **Commands**: `useradd`, `usermod`, `chown`, `find -user`

#### File System Labs  
- **Generator**: Create directory structures, mount points, files
- **Checker**: Verify mounts, directory permissions, file existence
- **Commands**: `mount`, `mkdir`, `chmod`, `ls -la`

#### Network Service Labs
- **Generator**: Configure services, create config files
- **Checker**: Verify service status, config files, network connectivity
- **Commands**: `systemctl`, `netstat`, `curl`

#### Package Management Labs
- **Generator**: Add repositories, install packages
- **Checker**: Verify repo configs, installed packages
- **Commands**: `dnf`, `yum`, `rpm -q`

### Standard Verification Patterns

#### File/Directory Checks
```bash
if [[ -f "/path/to/file" ]]; then
    echo -e "   ${GREEN}✓ PASS: File exists${NC}"
else
    echo -e "   ${RED}✗ FAIL: File missing${NC}"
fi
```

#### User/Service Checks  
```bash
if id "$username" &>/dev/null; then
    echo -e "   ${GREEN}✓ PASS: User exists${NC}"
else
    echo -e "   ${RED}✗ FAIL: User missing${NC}"
fi
```

#### Command History Evidence
```bash
if grep -q "expected_command" /root/.bash_history 2>/dev/null; then
    echo -e "   ${GREEN}✓ PASS: Command found in history${NC}"
else
    echo -e "   ${YELLOW}⚠ INFO: Command not in history${NC}"
fi
```

### AI Assistant Integration Tips

#### For Claude
- Provide clear requirements: "create user sally with files in home directory"
- Specify verification needs: "check if mounted at /home/shares"  
- Include expected commands: "user should have used dnf command"
- Request both generator AND checker scripts

#### For ChatGPT
- Be explicit about Linux distribution (RHEL/CentOS/Ubuntu)
- Specify shell requirements (bash, colors, logging)
- Request error handling and root privilege checks
- Ask for diagnostic information in failed checks

#### Sample Prompts
```
Create a bash script to generate a lab where:
1. User 'john' is created with home in /opt/users/john
2. User owns 5 files in different directories
3. Create checker script that verifies user exists, home location, and file ownership
4. Both scripts should log to ../../labresults.log
```

### Directory Structure
```
lab_scripts/
├── generators/
│   ├── generate_user_files.sh
│   ├── generate_nfs_setup.sh
│   └── generate_yum_repos.sh
├── checkers/
│   ├── usercheck.sh
│   ├── nfscheck.sh  
│   └── repocheck.sh
├── grading/
│   └── grade_labs.py
└── labresults.log
```

### Lab Grading System

#### Pass/Fail Grading with Improvement Tracking
The `grade_labs.py` script uses a **pass/fail system** while tracking command attempts to show student improvement over time:

**Grading Philosophy:**
- **Pass/Fail per Task**: Each task either passes or fails (no partial credit)
- **Improvement Tracking**: Counts attempts to show learning progress
- **Retry Success Recognition**: Celebrates tasks that succeeded after initial failure
- **Overall Lab Status**: Lab passes only if ALL tasks pass

**Key Metrics:**
- **First-try Successes**: Tasks passed on first attempt ⚡
- **Retry Successes**: Tasks that failed initially but later passed 📈  
- **Persistent Failures**: Tasks that failed despite multiple attempts 🔄
- **Total Attempts**: Shows effort and practice

**Usage Examples:**
```bash
# Basic pass/fail report with improvement tracking
python3 grade_labs.py

# JSON output for automated grading systems
python3 grade_labs.py --output-format json > grades.json

# HTML report showing improvement visually
python3 grade_labs.py --output-format html --output-file progress_report.html

# Grade specific log file
python3 grade_labs.py --log-file /path/to/custom.log
```

**Sample Output:**
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
Tasks requiring multiple attempts: 4
💪 Improvement shown: 4 tasks succeeded after retry!

DETAILED LAB ANALYSIS
----------------------------------------
USER MANAGEMENT
Status: PASS (5/5 tasks)
Total Attempts: 8 (avg: 1.6 per task)
✨ Improvement: 2 tasks succeeded after retry
⚡ First-try: 3 tasks passed immediately

Task Details:
  ✓ User Creation                PASS (1 attempt)
  ✓ User Home Directory          PASS (3 attempts) 📈
  ✓ File Ownership              PASS (2 attempts) 📈
  ✓ User Lab Complete           PASS (1 attempt)
```

**Improvement Indicators:**
- ⚡ **First-try success** - Passed on first attempt
- 📈 **Improved** - Failed initially, then succeeded  
- 🔄 **Still trying** - Multiple attempts, still failing

#### Integration with Lab Scripts
Lab scripts should log clear pass/fail results for each task:
```bash
log_result "PASS: User sally created successfully"
log_result "FAIL: Mount point /home/shares not found" 
log_result "PASS: Repository configuration verified"
log_result "FAIL: DNF command not found in history"

# Overall lab completion
log_result "VERIFICATION PASSED: All checks successful"
log_result "VERIFICATION FAILED: Some checks failed"
```

**Benefits:**
- **Clear Success Criteria**: Students know exactly what needs to pass
- **Encourages Persistence**: Shows improvement when students retry
- **Realistic Assessment**: Reflects real-world pass/fail scenarios
- **Progress Tracking**: Instructors can see student learning over time

### Quick Commands

#### Make All Scripts Executable
```bash
find . -name "*.sh" -exec chmod +x {} \;
```

#### Run Generator + Checker Sequence  
```bash
sudo ./generate_lab.sh && sudo ./labcheck.sh
```

#### Grade All Labs
```bash
# Generate text report
python3 grade_labs.py

# Generate JSON report  
python3 grade_labs.py --output-format json

# Generate HTML report and save
python3 grade_labs.py --output-format html --output-file report.html

# Grade specific log file
python3 grade_labs.py --log-file /path/to/labresults.log
```

#### View Results
```bash
tail -f ../../labresults.log
```

### Troubleshooting

#### Common Issues
1. **Permission Denied**: Always run with `sudo` for system changes
2. **Log File Missing**: Ensure `../../labresults.log` path is correct
3. **Colors Not Showing**: Check terminal supports ANSI colors
4. **Script Fails**: Add `set -e` and proper error handling

#### Debug Mode
Add to any script:
```bash
set -x  # Enable debug tracing
```

### Future Enhancements
- Add JSON output for automated testing
- Include timing metrics in logs  
- Add cleanup/reset functionality
- Create lab difficulty levels
- Add progress indicators for long-running tasks
- **Automated grade submission to LMS systems**
- **Trend analysis across multiple lab sessions**
- **Student progress tracking and analytics**