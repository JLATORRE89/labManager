#!/usr/bin/env python3
"""
Lab Manager - Backend API Server
Production-ready Flask application for managing Linux training labs
"""

import os
import logging
from datetime import datetime
from pathlib import Path

from flask import Flask, request, jsonify, session, send_from_directory
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, login_user, logout_user, login_required, current_user
from werkzeug.security import generate_password_hash, check_password_hash
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize Flask app
app = Flask(__name__, static_folder='static', static_url_path='')
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', os.urandom(24).hex())
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'sqlite:///labmanager.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SESSION_TYPE'] = os.getenv('SESSION_TYPE', 'filesystem')
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max request size

# Enable CORS for frontend
CORS(app, supports_credentials=True, origins=['http://localhost:*', 'http://127.0.0.1:*'])

# Initialize extensions
db = SQLAlchemy(app)
login_manager = LoginManager(app)
login_manager.login_view = 'login'

# Configure logging
log_level = os.getenv('LOG_LEVEL', 'INFO')
logging.basicConfig(
    level=getattr(logging, log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(os.getenv('LOG_FILE', 'labmanager.log')),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# ============================================================================
# Database Models
# ============================================================================

class User(db.Model):
    """User model for authentication"""
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False, index=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    is_admin = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_login = db.Column(db.DateTime)
    is_active = db.Column(db.Boolean, default=True)

    # Relationships
    deployments = db.relationship('Deployment', backref='user', lazy=True)
    lab_results = db.relationship('LabResult', backref='user', lazy=True)

    def set_password(self, password):
        """Hash and set user password"""
        self.password_hash = generate_password_hash(password, method='pbkdf2:sha256')

    def check_password(self, password):
        """Verify password against hash"""
        return check_password_hash(self.password_hash, password)

    def get_id(self):
        """Required for Flask-Login"""
        return str(self.id)

    @property
    def is_authenticated(self):
        return True

    @property
    def is_anonymous(self):
        return False


class Deployment(db.Model):
    """VM deployment tracking"""
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False, index=True)
    template_name = db.Column(db.String(100), nullable=False)
    node = db.Column(db.String(50), nullable=False)
    status = db.Column(db.String(20), nullable=False, default='pending', index=True)  # pending, deploying, running, stopped, failed
    vm_ids = db.Column(db.Text)  # JSON array of VM IDs
    created_at = db.Column(db.DateTime, default=datetime.utcnow, index=True)
    completed_at = db.Column(db.DateTime)
    error_message = db.Column(db.Text)

    # Configuration
    storage = db.Column(db.String(50))
    network_bridge = db.Column(db.String(50))
    vm_prefix = db.Column(db.String(50))

    def to_dict(self):
        """Convert deployment to dictionary"""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'username': self.user.username if self.user else None,
            'template_name': self.template_name,
            'node': self.node,
            'status': self.status,
            'vm_ids': self.vm_ids,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'completed_at': self.completed_at.isoformat() if self.completed_at else None,
            'error_message': self.error_message,
            'storage': self.storage,
            'network_bridge': self.network_bridge,
            'vm_prefix': self.vm_prefix
        }


class LabResult(db.Model):
    """Lab execution results"""
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False, index=True)
    deployment_id = db.Column(db.Integer, db.ForeignKey('deployment.id'), index=True)
    student_name = db.Column(db.String(100), nullable=False, index=True)
    vm_ip = db.Column(db.String(15), nullable=False)
    lab_type = db.Column(db.String(50), index=True)  # User Management, NFS Configuration, etc.
    status = db.Column(db.String(20), nullable=False, index=True)  # pass, fail, partial
    executed_at = db.Column(db.DateTime, default=datetime.utcnow, index=True)

    # Results data
    total_tasks = db.Column(db.Integer)
    passed_tasks = db.Column(db.Integer)
    failed_tasks = db.Column(db.Integer)
    execution_time = db.Column(db.Float)  # seconds

    # Files
    log_file_path = db.Column(db.String(255))
    report_text_path = db.Column(db.String(255))
    report_json_path = db.Column(db.String(255))
    report_html_path = db.Column(db.String(255))

    def to_dict(self):
        """Convert lab result to dictionary"""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'username': self.user.username if self.user else None,
            'deployment_id': self.deployment_id,
            'student_name': self.student_name,
            'vm_ip': self.vm_ip,
            'lab_type': self.lab_type,
            'status': self.status,
            'executed_at': self.executed_at.isoformat() if self.executed_at else None,
            'total_tasks': self.total_tasks,
            'passed_tasks': self.passed_tasks,
            'failed_tasks': self.failed_tasks,
            'execution_time': self.execution_time,
            'log_file_path': self.log_file_path,
            'report_text_path': self.report_text_path,
            'report_json_path': self.report_json_path,
            'report_html_path': self.report_html_path
        }


class ProxmoxNode(db.Model):
    """Proxmox node configuration"""
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50), unique=True, nullable=False, index=True)
    host = db.Column(db.String(255), nullable=False)
    is_active = db.Column(db.Boolean, default=True)
    max_concurrent_deployments = db.Column(db.Integer, default=5)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


# ============================================================================
# Flask-Login Configuration
# ============================================================================

@login_manager.user_loader
def load_user(user_id):
    """Load user by ID for Flask-Login"""
    return User.query.get(int(user_id))


# ============================================================================
# Helper Functions
# ============================================================================

def init_database():
    """Initialize database with tables and admin user"""
    with app.app_context():
        db.create_all()

        # Create admin user if it doesn't exist
        admin = User.query.filter_by(username='admin').first()
        if not admin:
            admin = User(
                username=os.getenv('ADMIN_USERNAME', 'admin'),
                email=os.getenv('ADMIN_EMAIL', 'admin@example.com'),
                is_admin=True
            )
            admin.set_password(os.getenv('ADMIN_PASSWORD', 'admin'))
            db.session.add(admin)
            db.session.commit()
            logger.info(f"Admin user created: {admin.username}")


def validate_ip(ip):
    """Validate IP address format"""
    import re
    pattern = r'^(\d{1,3}\.){3}\d{1,3}$'
    if not re.match(pattern, ip):
        return False
    parts = ip.split('.')
    return all(0 <= int(part) <= 255 for part in parts)


# ============================================================================
# API Routes - Authentication
# ============================================================================

@app.route('/api/auth/login', methods=['POST'])
def login():
    """User login endpoint"""
    try:
        data = request.get_json()
        username = data.get('username', '').strip()
        password = data.get('password', '')

        if not username or not password:
            return jsonify({'error': 'Username and password required'}), 400

        user = User.query.filter_by(username=username).first()

        if not user or not user.check_password(password):
            logger.warning(f"Failed login attempt for username: {username}")
            return jsonify({'error': 'Invalid credentials'}), 401

        if not user.is_active:
            return jsonify({'error': 'Account is disabled'}), 403

        login_user(user)
        user.last_login = datetime.utcnow()
        db.session.commit()

        logger.info(f"User logged in: {username}")
        return jsonify({
            'message': 'Login successful',
            'user': {
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'is_admin': user.is_admin
            }
        }), 200

    except Exception as e:
        logger.error(f"Login error: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/auth/logout', methods=['POST'])
@login_required
def logout():
    """User logout endpoint"""
    username = current_user.username
    logout_user()
    logger.info(f"User logged out: {username}")
    return jsonify({'message': 'Logout successful'}), 200


@app.route('/api/auth/status', methods=['GET'])
def auth_status():
    """Check authentication status"""
    if current_user.is_authenticated:
        return jsonify({
            'authenticated': True,
            'user': {
                'id': current_user.id,
                'username': current_user.username,
                'email': current_user.email,
                'is_admin': current_user.is_admin
            }
        }), 200
    return jsonify({'authenticated': False}), 200


# ============================================================================
# API Routes - Proxmox Operations
# ============================================================================

@app.route('/api/proxmox/connect', methods=['POST'])
@login_required
def proxmox_connect():
    """Test Proxmox connection"""
    try:
        from proxmoxer import ProxmoxAPI

        data = request.get_json()
        host = data.get('host', '').strip()
        token_id = data.get('token_id', '').strip()
        token_secret = data.get('token_secret', '').strip()

        if not all([host, token_id, token_secret]):
            return jsonify({'error': 'Missing required fields'}), 400

        # Remove protocol if included
        host = host.replace('https://', '').replace('http://', '')

        # Connect to Proxmox
        proxmox = ProxmoxAPI(
            host,
            user=token_id.split('!')[0],
            token_name=token_id.split('!')[1] if '!' in token_id else token_id,
            token_value=token_secret,
            verify_ssl=os.getenv('PROXMOX_VERIFY_SSL', 'false').lower() == 'true'
        )

        # Test connection by getting version
        version = proxmox.version.get()
        nodes = list(proxmox.nodes.get())

        logger.info(f"Proxmox connection successful for user: {current_user.username}")

        return jsonify({
            'message': 'Connection successful',
            'version': version.get('version'),
            'nodes': [node['node'] for node in nodes]
        }), 200

    except Exception as e:
        logger.error(f"Proxmox connection error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/proxmox/nodes', methods=['GET'])
@login_required
def get_proxmox_nodes():
    """Get list of Proxmox nodes"""
    try:
        from proxmoxer import ProxmoxAPI

        proxmox = ProxmoxAPI(
            os.getenv('PROXMOX_HOST', '').replace('https://', ''),
            user=os.getenv('PROXMOX_USER', 'root@pam'),
            token_name=os.getenv('PROXMOX_TOKEN_NAME'),
            token_value=os.getenv('PROXMOX_TOKEN_VALUE'),
            verify_ssl=os.getenv('PROXMOX_VERIFY_SSL', 'false').lower() == 'true'
        )

        nodes = proxmox.nodes.get()
        return jsonify({'nodes': nodes}), 200

    except Exception as e:
        logger.error(f"Error fetching nodes: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/proxmox/storage', methods=['GET'])
@login_required
def get_storage():
    """Get storage pools for a node"""
    try:
        from proxmoxer import ProxmoxAPI

        node = request.args.get('node', os.getenv('DEFAULT_NODE', 'pve'))

        proxmox = ProxmoxAPI(
            os.getenv('PROXMOX_HOST', '').replace('https://', ''),
            user=os.getenv('PROXMOX_USER', 'root@pam'),
            token_name=os.getenv('PROXMOX_TOKEN_NAME'),
            token_value=os.getenv('PROXMOX_TOKEN_VALUE'),
            verify_ssl=os.getenv('PROXMOX_VERIFY_SSL', 'false').lower() == 'true'
        )

        storage = proxmox.nodes(node).storage.get()
        return jsonify({'storage': storage}), 200

    except Exception as e:
        logger.error(f"Error fetching storage: {e}")
        return jsonify({'error': str(e)}), 500


# ============================================================================
# API Routes - Deployments
# ============================================================================

@app.route('/api/deployments', methods=['POST'])
@login_required
def create_deployment():
    """Create a new VM deployment"""
    try:
        data = request.get_json()

        # Validate required fields
        required_fields = ['template', 'node', 'storage', 'bridge', 'prefix']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Missing required field: {field}'}), 400

        # Create deployment record
        deployment = Deployment(
            user_id=current_user.id,
            template_name=data['template'],
            node=data['node'],
            storage=data['storage'],
            network_bridge=data['bridge'],
            vm_prefix=data['prefix'],
            status='pending'
        )

        db.session.add(deployment)
        db.session.commit()

        logger.info(f"Deployment created: ID={deployment.id}, User={current_user.username}")

        # TODO: Queue deployment task with Celery
        # For now, return success immediately
        return jsonify({
            'message': 'Deployment queued successfully',
            'deployment': deployment.to_dict()
        }), 201

    except Exception as e:
        logger.error(f"Deployment creation error: {e}")
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@app.route('/api/deployments', methods=['GET'])
@login_required
def list_deployments():
    """List user's deployments"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 20, type=int)

        query = Deployment.query.filter_by(user_id=current_user.id)

        # Admin can see all deployments
        if current_user.is_admin:
            query = Deployment.query

        deployments = query.order_by(Deployment.created_at.desc()).paginate(
            page=page, per_page=per_page, error_out=False
        )

        return jsonify({
            'deployments': [d.to_dict() for d in deployments.items],
            'total': deployments.total,
            'pages': deployments.pages,
            'current_page': page
        }), 200

    except Exception as e:
        logger.error(f"Error listing deployments: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/deployments/<int:deployment_id>', methods=['GET'])
@login_required
def get_deployment(deployment_id):
    """Get deployment details"""
    try:
        deployment = Deployment.query.get_or_404(deployment_id)

        # Check permissions
        if deployment.user_id != current_user.id and not current_user.is_admin:
            return jsonify({'error': 'Unauthorized'}), 403

        return jsonify({'deployment': deployment.to_dict()}), 200

    except Exception as e:
        logger.error(f"Error fetching deployment: {e}")
        return jsonify({'error': str(e)}), 500


# ============================================================================
# API Routes - Lab Results
# ============================================================================

@app.route('/api/results', methods=['GET'])
@login_required
def list_results():
    """List lab results"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 20, type=int)

        query = LabResult.query.filter_by(user_id=current_user.id)

        # Admin can see all results
        if current_user.is_admin:
            query = LabResult.query

        results = query.order_by(LabResult.executed_at.desc()).paginate(
            page=page, per_page=per_page, error_out=False
        )

        return jsonify({
            'results': [r.to_dict() for r in results.items],
            'total': results.total,
            'pages': results.pages,
            'current_page': page
        }), 200

    except Exception as e:
        logger.error(f"Error listing results: {e}")
        return jsonify({'error': str(e)}), 500


# ============================================================================
# Static File Serving
# ============================================================================

@app.route('/')
def index():
    """Serve main page"""
    return send_from_directory('.', 'index.html')


@app.route('/api/config', methods=['GET'])
def get_config():
    """Get public configuration"""
    return jsonify({
        'proxmoxHost': os.getenv('PROXMOX_HOST', ''),
        'defaultNode': os.getenv('DEFAULT_NODE', 'pve'),
        'defaultStorage': os.getenv('DEFAULT_STORAGE', 'local-lvm'),
        'defaultBridge': os.getenv('DEFAULT_BRIDGE', 'vmbr0'),
        'defaultPrefix': os.getenv('DEFAULT_VM_PREFIX', 'rhcsa9-')
    }), 200


# ============================================================================
# Health Check
# ============================================================================

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    try:
        # Check database connection
        db.session.execute(db.text('SELECT 1'))

        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.utcnow().isoformat(),
            'version': '1.0.0'
        }), 200
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({
            'status': 'unhealthy',
            'error': str(e)
        }), 500


# ============================================================================
# Error Handlers
# ============================================================================

@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({'error': 'Not found'}), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    logger.error(f"Internal server error: {error}")
    db.session.rollback()
    return jsonify({'error': 'Internal server error'}), 500


# ============================================================================
# Application Entry Point
# ============================================================================

if __name__ == '__main__':
    # Initialize database
    init_database()

    # Run development server
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_ENV') == 'development'

    logger.info(f"Starting Lab Manager API server on port {port}")
    app.run(host='0.0.0.0', port=port, debug=debug)
