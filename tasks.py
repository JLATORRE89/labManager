#!/usr/bin/env python3
"""
Celery Tasks for Background Job Processing
Handles VM deployment and lab execution
"""

import os
import json
import time
from datetime import datetime
from pathlib import Path

from celery import Celery
from proxmoxer import ProxmoxAPI
import paramiko

# Initialize Celery
celery = Celery(
    'labmanager',
    broker=os.getenv('REDIS_URL', 'redis://localhost:6379/0'),
    backend=os.getenv('REDIS_URL', 'redis://localhost:6379/0')
)

celery.conf.update(
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='UTC',
    enable_utc=True,
)


def get_proxmox_client():
    """Get Proxmox API client"""
    host = os.getenv('PROXMOX_HOST', '').replace('https://', '').replace('http://', '')
    return ProxmoxAPI(
        host,
        user=os.getenv('PROXMOX_USER', 'root@pam'),
        token_name=os.getenv('PROXMOX_TOKEN_NAME'),
        token_value=os.getenv('PROXMOX_TOKEN_VALUE'),
        verify_ssl=os.getenv('PROXMOX_VERIFY_SSL', 'false').lower() == 'true'
    )


@celery.task(bind=True)
def deploy_lab_environment(self, deployment_id, config):
    """
    Deploy lab VMs on Proxmox

    Args:
        deployment_id: Database ID of deployment
        config: Deployment configuration dict
    """
    try:
        from app import app, db, Deployment

        self.update_state(state='PROGRESS', meta={'status': 'Connecting to Proxmox'})

        proxmox = get_proxmox_client()
        node = config['node']
        template = config['template']
        storage = config['storage']
        bridge = config['network_bridge']
        prefix = config['vm_prefix']

        # Get next available VM ID
        next_vmid = proxmox.cluster.nextid.get()

        vm_ids = []
        vm_configs = []

        # Determine VMs to create based on template
        if template == 'rhcsa9-base':
            vms_to_create = [
                {'name': f'{prefix}server', 'cores': 2, 'memory': 2048},
                {'name': f'{prefix}client', 'cores': 2, 'memory': 2048}
            ]
        else:  # rhcsa9-extended
            vms_to_create = [
                {'name': f'{prefix}server', 'cores': 2, 'memory': 2048},
                {'name': f'{prefix}client1', 'cores': 2, 'memory': 2048},
                {'name': f'{prefix}client2', 'cores': 2, 'memory': 2048}
            ]

        total_vms = len(vms_to_create)

        # Create VMs
        for idx, vm_config in enumerate(vms_to_create, 1):
            self.update_state(
                state='PROGRESS',
                meta={'status': f'Creating VM {idx}/{total_vms}: {vm_config["name"]}'}
            )

            vmid = next_vmid + idx - 1

            # Create VM
            proxmox.nodes(node).qemu.create(
                vmid=vmid,
                name=vm_config['name'],
                cores=vm_config['cores'],
                memory=vm_config['memory'],
                net0=f'virtio,bridge={bridge}',
                scsihw='virtio-scsi-pci',
                bootdisk='scsi0',
                ostype='l26',  # Linux 2.6+
            )

            # Add disk
            proxmox.nodes(node).qemu(vmid).config.put(
                scsi0=f'{storage}:32,format=qcow2'
            )

            vm_ids.append(vmid)
            vm_configs.append({
                'vmid': vmid,
                'name': vm_config['name'],
                'cores': vm_config['cores'],
                'memory': vm_config['memory']
            })

            # Start VM
            self.update_state(
                state='PROGRESS',
                meta={'status': f'Starting VM {idx}/{total_vms}: {vm_config["name"]}'}
            )
            proxmox.nodes(node).qemu(vmid).status.start.post()

            # Wait a bit between VM creations
            time.sleep(2)

        # Update deployment in database
        with app.app_context():
            deployment = Deployment.query.get(deployment_id)
            if deployment:
                deployment.status = 'running'
                deployment.vm_ids = json.dumps(vm_configs)
                deployment.completed_at = datetime.utcnow()
                db.session.commit()

        return {
            'status': 'success',
            'message': f'Successfully deployed {total_vms} VMs',
            'vm_ids': vm_configs
        }

    except Exception as e:
        # Update deployment status to failed
        try:
            with app.app_context():
                deployment = Deployment.query.get(deployment_id)
                if deployment:
                    deployment.status = 'failed'
                    deployment.error_message = str(e)
                    deployment.completed_at = datetime.utcnow()
                    db.session.commit()
        except:
            pass

        self.update_state(state='FAILURE', meta={'error': str(e)})
        raise


@celery.task(bind=True)
def execute_lab(self, lab_result_id, config):
    """
    Execute lab scripts on remote VM

    Args:
        lab_result_id: Database ID of lab result
        config: Lab execution configuration
    """
    try:
        from app import app, db, LabResult
        import subprocess

        self.update_state(state='PROGRESS', meta={'status': 'Preparing lab execution'})

        vm_ip = config['vm_ip']
        vm_user = config.get('vm_user', 'root')
        vm_password = config.get('vm_password')
        ssh_key = config.get('ssh_key')
        student_name = config['student_name']

        # Build command to run orchestrator script
        cmd = [
            './scripts/run_vm_labs.sh',
            '--vm-ip', vm_ip,
            '--vm-user', vm_user,
            '--student-name', student_name
        ]

        if ssh_key:
            cmd.extend(['--ssh-key', ssh_key])
        elif vm_password:
            cmd.extend(['--vm-password', vm_password])
        else:
            raise ValueError('Either ssh_key or vm_password must be provided')

        # Execute lab orchestrator
        self.update_state(state='PROGRESS', meta={'status': 'Running lab scripts'})

        start_time = time.time()
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=int(os.getenv('LAB_EXECUTION_TIMEOUT', 300))
        )
        execution_time = time.time() - start_time

        # Parse results from generated files
        completed_dir = Path('./completedLabs')
        report_files = list(completed_dir.glob(f'{student_name}_*'))

        if report_files:
            # Find the most recent report
            latest_report = max(report_files, key=lambda p: p.stat().st_mtime)
            report_prefix = latest_report.stem.rsplit('_', 1)[0]

            text_report = completed_dir / f'{report_prefix}_report.txt'
            json_report = completed_dir / f'{report_prefix}_grades.json'
            html_report = completed_dir / f'{report_prefix}_report.html'

            # Parse JSON report for statistics
            stats = {'total_tasks': 0, 'passed_tasks': 0, 'failed_tasks': 0, 'status': 'fail'}
            if json_report.exists():
                with open(json_report, 'r') as f:
                    data = json.load(f)
                    summary = data.get('summary', {})
                    stats['total_tasks'] = summary.get('total_entries', 0)
                    stats['status'] = data.get('overall_status', 'fail').lower()

                    # Count passed/failed from lab results
                    for lab_name, lab_data in data.get('lab_results', {}).items():
                        stats['passed_tasks'] += lab_data.get('passed_tasks', 0)
                        stats['failed_tasks'] += (lab_data.get('total_tasks', 0) -
                                                 lab_data.get('passed_tasks', 0))

            # Update lab result in database
            with app.app_context():
                lab_result = LabResult.query.get(lab_result_id)
                if lab_result:
                    lab_result.status = stats['status']
                    lab_result.total_tasks = stats['total_tasks']
                    lab_result.passed_tasks = stats['passed_tasks']
                    lab_result.failed_tasks = stats['failed_tasks']
                    lab_result.execution_time = execution_time
                    lab_result.log_file_path = str(Path('labresults.log').absolute())
                    lab_result.report_text_path = str(text_report) if text_report.exists() else None
                    lab_result.report_json_path = str(json_report) if json_report.exists() else None
                    lab_result.report_html_path = str(html_report) if html_report.exists() else None
                    db.session.commit()

        return {
            'status': 'success',
            'execution_time': execution_time,
            'stats': stats
        }

    except Exception as e:
        self.update_state(state='FAILURE', meta={'error': str(e)})
        raise


@celery.task
def cleanup_old_deployments(days=30):
    """Clean up old deployments and associated VMs"""
    from app import app, db, Deployment
    from datetime import timedelta

    with app.app_context():
        cutoff_date = datetime.utcnow() - timedelta(days=days)
        old_deployments = Deployment.query.filter(
            Deployment.created_at < cutoff_date,
            Deployment.status.in_(['stopped', 'failed'])
        ).all()

        proxmox = get_proxmox_client()

        for deployment in old_deployments:
            try:
                if deployment.vm_ids:
                    vm_configs = json.loads(deployment.vm_ids)
                    for vm_config in vm_configs:
                        vmid = vm_config.get('vmid')
                        if vmid:
                            try:
                                # Stop and delete VM
                                proxmox.nodes(deployment.node).qemu(vmid).status.stop.post()
                                time.sleep(2)
                                proxmox.nodes(deployment.node).qemu(vmid).delete()
                            except:
                                pass  # VM may already be deleted

                db.session.delete(deployment)
            except:
                pass

        db.session.commit()

        return {'status': 'success', 'cleaned': len(old_deployments)}
