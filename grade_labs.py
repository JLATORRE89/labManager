#!/usr/bin/env python3
"""
Lab Grading System - Pass/Fail with Improvement Tracking
Reads labresults.log and generates pass/fail grades with attempt analysis
Usage: python3 grade_labs.py [--log-file path] [--output-format text|json|html]
"""

import re
import json
import argparse
from datetime import datetime
from collections import defaultdict, Counter
from pathlib import Path

class LabGrader:
    def __init__(self, log_file="labresults.log"):
        self.log_file = Path(log_file)
        self.results = []
        self.lab_sessions = defaultdict(list)
        self.task_attempts = defaultdict(list)  # Track attempts per task
        self.final_status = {}  # Final pass/fail status per task
        
    def parse_log_file(self):
        """Parse the labresults.log file and extract all test results"""
        if not self.log_file.exists():
            raise FileNotFoundError(f"Log file {self.log_file} not found")
            
        with open(self.log_file, 'r') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if not line:
                    continue
                    
                # Parse log entry format: "timestamp: STATUS: message"
                match = re.match(r'(.+?):\s+(PASS|FAIL|PARTIAL|INFO|VERIFICATION PASSED|VERIFICATION FAILED|NFS VERIFICATION PASSED|NFS VERIFICATION FAILED|YUM REPO VERIFICATION PASSED|YUM REPO VERIFICATION FAILED):\s+(.+)', line)
                
                if match:
                    timestamp_str, status, message = match.groups()
                    
                    try:
                        # Try to parse timestamp
                        timestamp = datetime.strptime(timestamp_str.strip(), "%a %b %d %H:%M:%S %Z %Y")
                    except ValueError:
                        try:
                            # Alternative timestamp format
                            timestamp = datetime.strptime(timestamp_str.strip(), "%Y-%m-%d %H:%M:%S")
                        except ValueError:
                            # Use current time if parsing fails
                            timestamp = datetime.now()
                    
                    # Normalize status for overall verification results
                    if "PASSED" in status:
                        status = "PASS"
                    elif "FAILED" in status:
                        status = "FAIL"
                        
                    result = {
                        'line_number': line_num,
                        'timestamp': timestamp,
                        'status': status,
                        'message': message.strip(),
                        'raw_line': line
                    }
                    
                    self.results.append(result)
                    
                    # Group by lab type and track task attempts
                    lab_type = self._identify_lab_type(message)
                    task_name = self._extract_task_name(message)
                    
                    self.lab_sessions[lab_type].append(result)
                    self.task_attempts[task_name].append({
                        'timestamp': timestamp,
                        'status': status,
                        'lab_type': lab_type,
                        'message': message
                    })
                    
                    # Update final status (latest attempt wins)
                    if status in ['PASS', 'FAIL']:
                        self.final_status[task_name] = {
                            'status': status,
                            'timestamp': timestamp,
                            'lab_type': lab_type,
                            'attempts': len(self.task_attempts[task_name])
                        }
    
    def _identify_lab_type(self, message):
        """Identify lab type based on message content"""
        message_lower = message.lower()
        
        if any(keyword in message_lower for keyword in ['user', 'sally', 'eric', 'file collection']):
            return 'User Management'
        elif any(keyword in message_lower for keyword in ['nfs', 'mount', 'shares', 'usershare']):
            return 'NFS Configuration'
        elif any(keyword in message_lower for keyword in ['yum', 'dnf', 'repository', 'repo', 'example.com']):
            return 'Package Management'
        elif any(keyword in message_lower for keyword in ['network', 'service', 'daemon']):
            return 'Network Services'
        elif any(keyword in message_lower for keyword in ['file', 'directory', 'permission']):
            return 'File System'
        else:
            return 'General'
    
    def _extract_task_name(self, message):
        """Extract specific task name from message for tracking attempts"""
        message_lower = message.lower()
        
        # Common task patterns - extract the core task being tested
        if 'user' in message_lower and 'exists' in message_lower:
            return 'User Creation'
        elif 'user' in message_lower and 'home' in message_lower:
            return 'User Home Directory'
        elif 'files' in message_lower and ('owned' in message_lower or 'collection' in message_lower):
            return 'File Ownership'
        elif 'mount' in message_lower and any(x in message_lower for x in ['nfs', 'shares']):
            return 'NFS Mount'
        elif 'fstab' in message_lower:
            return 'FSTAB Configuration'
        elif any(x in message_lower for x in ['repository', 'repo']) and 'example.com' in message_lower:
            return 'Repository Configuration'
        elif 'dnf' in message_lower and ('command' in message_lower or 'usage' in message_lower):
            return 'DNF Command Usage'
        elif 'verification passed' in message_lower:
            if 'nfs' in message_lower:
                return 'NFS Lab Complete'
            elif 'repo' in message_lower or 'yum' in message_lower:
                return 'Repository Lab Complete'
            else:
                return 'User Lab Complete'
        elif 'verification failed' in message_lower:
            if 'nfs' in message_lower:
                return 'NFS Lab Complete'
            elif 'repo' in message_lower or 'yum' in message_lower:
                return 'Repository Lab Complete'
            else:
                return 'User Lab Complete'
        else:
            # Generic task name based on first few words
            words = message.split()[:3]
            return ' '.join(words).title()
    
    def calculate_lab_results(self):
        """Calculate pass/fail results and improvement metrics"""
        lab_results = {}
        
        for lab_type in self.lab_sessions.keys():
            # Get all tasks for this lab type
            lab_tasks = {task: info for task, info in self.final_status.items() 
                        if info['lab_type'] == lab_type}
            
            if not lab_tasks:
                continue
                
            passed_tasks = sum(1 for info in lab_tasks.values() if info['status'] == 'PASS')
            total_tasks = len(lab_tasks)
            total_attempts = sum(info['attempts'] for info in lab_tasks.values())
            
            # Calculate improvement metrics
            improvement_data = self._calculate_improvement_metrics(lab_type, lab_tasks)
            
            lab_results[lab_type] = {
                'passed_tasks': passed_tasks,
                'total_tasks': total_tasks,
                'pass_rate': (passed_tasks / total_tasks * 100) if total_tasks > 0 else 0,
                'overall_status': 'PASS' if passed_tasks == total_tasks else 'FAIL',
                'total_attempts': total_attempts,
                'average_attempts': total_attempts / total_tasks if total_tasks > 0 else 0,
                'tasks': lab_tasks,
                'improvement': improvement_data
            }
        
        return lab_results
    
    def _calculate_improvement_metrics(self, lab_type, lab_tasks):
        """Calculate improvement metrics for a lab"""
        improvement_data = {
            'retry_success_count': 0,
            'first_try_success_count': 0,
            'persistent_failures': 0,
            'max_attempts': 0,
            'tasks_with_multiple_attempts': 0
        }
        
        for task_name, task_info in lab_tasks.items():
            attempts = task_info['attempts']
            status = task_info['status']
            
            improvement_data['max_attempts'] = max(improvement_data['max_attempts'], attempts)
            
            if attempts > 1:
                improvement_data['tasks_with_multiple_attempts'] += 1
                if status == 'PASS':
                    improvement_data['retry_success_count'] += 1
                else:
                    improvement_data['persistent_failures'] += 1
            elif attempts == 1 and status == 'PASS':
                improvement_data['first_try_success_count'] += 1
        
        return improvement_data
    
    def generate_text_report(self):
        """Generate a comprehensive text-based grade report"""
        if not self.results:
            return "No lab results found in log file."
            
        lab_results = self.calculate_lab_results()
        
        report = []
        report.append("=" * 80)
        report.append("LAB GRADING REPORT - PASS/FAIL WITH IMPROVEMENT TRACKING")
        report.append("=" * 80)
        report.append(f"Report Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append(f"Log File: {self.log_file}")
        report.append(f"Total Log Entries: {len(self.results)}")
        report.append("")
        
        # Overall Summary
        total_labs = len(lab_results)
        passed_labs = sum(1 for result in lab_results.values() if result['overall_status'] == 'PASS')
        
        report.append("OVERALL SUMMARY")
        report.append("-" * 40)
        report.append(f"Total Labs: {total_labs}")
        report.append(f"Labs Passed: {passed_labs}")
        report.append(f"Labs Failed: {total_labs - passed_labs}")
        report.append(f"Overall Status: {'PASS' if passed_labs == total_labs else 'FAIL'}")
        report.append("")
        
        # Individual Lab Results
        report.append("LAB RESULTS")
        report.append("-" * 40)
        
        for lab_type, result in sorted(lab_results.items()):
            status_symbol = "✓" if result['overall_status'] == 'PASS' else "✗"
            report.append(f"{status_symbol} {lab_type:25}: {result['overall_status']:4} "
                         f"({result['passed_tasks']}/{result['total_tasks']} tasks, "
                         f"{result['total_attempts']} total attempts)")
        
        report.append("")
        
        # Improvement Analysis
        report.append("IMPROVEMENT ANALYSIS")
        report.append("-" * 40)
        
        total_retry_successes = sum(r['improvement']['retry_success_count'] for r in lab_results.values())
        total_first_try_successes = sum(r['improvement']['first_try_success_count'] for r in lab_results.values())
        total_multiple_attempt_tasks = sum(r['improvement']['tasks_with_multiple_attempts'] for r in lab_results.values())
        
        report.append(f"First-try successes: {total_first_try_successes}")
        report.append(f"Retry successes: {total_retry_successes}")
        report.append(f"Tasks requiring multiple attempts: {total_multiple_attempt_tasks}")
        
        if total_retry_successes > 0:
            report.append(f"💪 Improvement shown: {total_retry_successes} tasks succeeded after retry!")
        
        report.append("")
        
        # Detailed Lab Analysis
        report.append("DETAILED LAB ANALYSIS")
        report.append("-" * 80)
        
        for lab_type, result in sorted(lab_results.items()):
            report.append(f"\n{lab_type.upper()}")
            report.append("-" * len(lab_type))
            report.append(f"Status: {result['overall_status']} ({result['passed_tasks']}/{result['total_tasks']} tasks)")
            report.append(f"Total Attempts: {result['total_attempts']} (avg: {result['average_attempts']:.1f} per task)")
            
            # Improvement metrics for this lab
            imp = result['improvement']
            if imp['retry_success_count'] > 0:
                report.append(f"✨ Improvement: {imp['retry_success_count']} tasks succeeded after retry")
            if imp['first_try_success_count'] > 0:
                report.append(f"⚡ First-try: {imp['first_try_success_count']} tasks passed immediately")
            if imp['persistent_failures'] > 0:
                report.append(f"⚠️  Persistent: {imp['persistent_failures']} tasks failed despite retries")
            
            report.append("")
            report.append("Task Details:")
            
            for task_name, task_info in sorted(result['tasks'].items()):
                status_symbol = "✓" if task_info['status'] == 'PASS' else "✗"
                attempts_str = f"({task_info['attempts']} attempts)" if task_info['attempts'] > 1 else "(1 attempt)"
                
                improvement_indicator = ""
                if task_info['attempts'] > 1 and task_info['status'] == 'PASS':
                    improvement_indicator = " 📈"
                elif task_info['attempts'] > 1 and task_info['status'] == 'FAIL':
                    improvement_indicator = " 🔄"
                
                report.append(f"  {status_symbol} {task_name:30} {task_info['status']:4} {attempts_str}{improvement_indicator}")
        
        # Recommendations
        report.append("")
        report.append("RECOMMENDATIONS")
        report.append("-" * 40)
        
        failed_labs = [name for name, result in lab_results.items() if result['overall_status'] == 'FAIL']
        
        if not failed_labs:
            report.append("🎉 Excellent! All labs passed successfully!")
            if total_retry_successes > 0:
                report.append("👏 Great persistence shown - you improved through practice!")
        else:
            report.append(f"📚 Focus on these failed labs: {', '.join(failed_labs)}")
            if total_retry_successes > 0:
                report.append("👍 You're showing good improvement - keep practicing!")
            
            # Show tasks that need attention
            persistent_failures = []
            for lab_type, result in lab_results.items():
                for task_name, task_info in result['tasks'].items():
                    if task_info['status'] == 'FAIL' and task_info['attempts'] > 1:
                        persistent_failures.append(f"{lab_type}: {task_name}")
            
            if persistent_failures:
                report.append("")
                report.append("Tasks needing extra attention (failed despite retries):")
                for task in persistent_failures[:5]:  # Show top 5
                    report.append(f"  • {task}")
        
        report.append("")
        report.append("=" * 80)
        
        return "\n".join(report)
    
    def generate_json_report(self):
        """Generate JSON format report for programmatic use"""
        lab_results = self.calculate_lab_results()
        
        # Calculate overall metrics
        total_labs = len(lab_results)
        passed_labs = sum(1 for result in lab_results.values() if result['overall_status'] == 'PASS')
        total_retry_successes = sum(r['improvement']['retry_success_count'] for r in lab_results.values())
        total_first_try_successes = sum(r['improvement']['first_try_success_count'] for r in lab_results.values())
        
        report_data = {
            'report_generated': datetime.now().isoformat(),
            'log_file': str(self.log_file),
            'overall_status': 'PASS' if passed_labs == total_labs else 'FAIL',
            'summary': {
                'total_labs': total_labs,
                'labs_passed': passed_labs,
                'labs_failed': total_labs - passed_labs,
                'total_entries': len(self.results)
            },
            'improvement_metrics': {
                'first_try_successes': total_first_try_successes,
                'retry_successes': total_retry_successes,
                'total_multiple_attempt_tasks': sum(r['improvement']['tasks_with_multiple_attempts'] for r in lab_results.values()),
                'improvement_shown': total_retry_successes > 0
            },
            'lab_results': {}
        }
        
        # Add detailed lab results
        for lab_type, result in lab_results.items():
            report_data['lab_results'][lab_type] = {
                'overall_status': result['overall_status'],
                'passed_tasks': result['passed_tasks'],
                'total_tasks': result['total_tasks'],
                'pass_rate': result['pass_rate'],
                'total_attempts': result['total_attempts'],
                'average_attempts': result['average_attempts'],
                'improvement_metrics': result['improvement'],
                'tasks': {
                    task_name: {
                        'status': task_info['status'],
                        'attempts': task_info['attempts'],
                        'timestamp': task_info['timestamp'].isoformat()
                    }
                    for task_name, task_info in result['tasks'].items()
                }
            }
        
        return json.dumps(report_data, indent=2)
    
    def generate_html_report(self):
        """Generate HTML format report"""
        lab_results = self.calculate_lab_results()
        
        # Calculate overall metrics
        total_labs = len(lab_results)
        passed_labs = sum(1 for result in lab_results.values() if result['overall_status'] == 'PASS')
        total_retry_successes = sum(r['improvement']['retry_success_count'] for r in lab_results.values())
        overall_status = 'PASS' if passed_labs == total_labs else 'FAIL'
        
        html = f"""
<!DOCTYPE html>
<html>
<head>
    <title>Lab Grading Report - Pass/Fail with Improvement Tracking</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 40px; }}
        .header {{ background: #2c3e50; color: white; padding: 20px; border-radius: 5px; }}
        .summary-cards {{ display: flex; gap: 20px; margin: 20px 0; }}
        .card {{ background: #ecf0f1; padding: 15px; border-radius: 5px; flex: 1; text-align: center; }}
        .pass-card {{ background: #d5f4e6; }}
        .fail-card {{ background: #fdeaea; }}
        .improvement-card {{ background: #fff3cd; }}
        .lab-section {{ margin: 20px 0; }}
        .pass {{ color: #27ae60; font-weight: bold; }}
        .fail {{ color: #e74c3c; font-weight: bold; }}
        .task-table {{ width: 100%; border-collapse: collapse; margin: 10px 0; }}
        .task-table th, .task-table td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
        .task-table th {{ background-color: #f2f2f2; }}
        .improvement-icon {{ font-size: 1.2em; }}
        .lab-header {{ background: #34495e; color: white; padding: 10px; margin: 15px 0 5px 0; }}
    </style>
</head>
<body>
    <div class="header">
        <h1>Lab Grading Report - Pass/Fail with Improvement Tracking</h1>
        <p>Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
        <p>Log File: {self.log_file}</p>
    </div>
    
    <div class="summary-cards">
        <div class="card {'pass-card' if overall_status == 'PASS' else 'fail-card'}">
            <h3>Overall Status</h3>
            <h2 class="{'pass' if overall_status == 'PASS' else 'fail'}">{overall_status}</h2>
            <p>{passed_labs}/{total_labs} Labs Passed</p>
        </div>
        <div class="card">
            <h3>Total Attempts</h3>
            <h2>{sum(r['total_attempts'] for r in lab_results.values())}</h2>
            <p>Across all tasks</p>
        </div>
        <div class="card improvement-card">
            <h3>Improvement Shown</h3>
            <h2>{total_retry_successes}</h2>
            <p>Tasks succeeded after retry</p>
        </div>
    </div>
"""
        
        # Lab results table
        html += """
    <div class="lab-section">
        <h2>Lab Results Summary</h2>
        <table class="task-table">
            <tr><th>Lab Type</th><th>Status</th><th>Tasks</th><th>Attempts</th><th>Improvement</th></tr>
"""
        
        for lab_type, result in sorted(lab_results.items()):
            status_class = 'pass' if result['overall_status'] == 'PASS' else 'fail'
            improvement_icon = '📈' if result['improvement']['retry_success_count'] > 0 else ''
            
            html += f"""
            <tr>
                <td>{lab_type}</td>
                <td class="{status_class}">{result['overall_status']}</td>
                <td>{result['passed_tasks']}/{result['total_tasks']}</td>
                <td>{result['total_attempts']} (avg: {result['average_attempts']:.1f})</td>
                <td>{improvement_icon} {result['improvement']['retry_success_count']} retries succeeded</td>
            </tr>"""
        
        html += """
        </table>
    </div>
"""
        
        # Detailed lab breakdown
        for lab_type, result in sorted(lab_results.items()):
            html += f"""
    <div class="lab-header">
        <h3>{lab_type} - {'✓' if result['overall_status'] == 'PASS' else '✗'} {result['overall_status']}</h3>
    </div>
    <table class="task-table">
        <tr><th>Task</th><th>Status</th><th>Attempts</th><th>Progress</th></tr>
"""
            
            for task_name, task_info in sorted(result['tasks'].items()):
                status_class = 'pass' if task_info['status'] == 'PASS' else 'fail'
                
                progress_icon = ""
                if task_info['attempts'] > 1 and task_info['status'] == 'PASS':
                    progress_icon = '<span class="improvement-icon">📈</span>'
                elif task_info['attempts'] > 1 and task_info['status'] == 'FAIL':
                    progress_icon = '<span class="improvement-icon">🔄</span>'
                elif task_info['attempts'] == 1 and task_info['status'] == 'PASS':
                    progress_icon = '<span class="improvement-icon">⚡</span>'
                
                html += f"""
        <tr>
            <td>{task_name}</td>
            <td class="{status_class}">{task_info['status']}</td>
            <td>{task_info['attempts']}</td>
            <td>{progress_icon}</td>
        </tr>"""
            
            html += "</table>"
        
        html += """
</body>
</html>"""
        
        return html

def main():
    parser = argparse.ArgumentParser(description='Grade lab results from log file')
    parser.add_argument('--log-file', default='labresults.log', 
                       help='Path to lab results log file (default: labresults.log)')
    parser.add_argument('--output-format', choices=['text', 'json', 'html'], default='text',
                       help='Output format (default: text)')
    parser.add_argument('--output-file', help='Save report to file instead of stdout')
    
    args = parser.parse_args()
    
    try:
        grader = LabGrader(args.log_file)
        grader.parse_log_file()
        
        if args.output_format == 'json':
            report = grader.generate_json_report()
        elif args.output_format == 'html':
            report = grader.generate_html_report()
        else:
            report = grader.generate_text_report()
        
        if args.output_file:
            with open(args.output_file, 'w') as f:
                f.write(report)
            print(f"Report saved to {args.output_file}")
        else:
            print(report)
            
    except FileNotFoundError as e:
        print(f"Error: {e}")
        return 1
    except Exception as e:
        print(f"Unexpected error: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())