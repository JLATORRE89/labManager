#!/usr/bin/env python3
"""
Basic tests for Lab Manager MVP
Run with: python3 test_app.py
"""

import sys
import os

def test_imports():
    """Test that all required modules can be imported"""
    print("Testing imports...")
    try:
        import flask
        import flask_cors
        import flask_sqlalchemy
        import flask_login
        import proxmoxer
        import celery
        import redis
        import paramiko
        print("✓ All required modules can be imported")
        return True
    except ImportError as e:
        print(f"✗ Import error: {e}")
        print("Run: pip install -r requirements.txt")
        return False


def test_env_file():
    """Test that .env file exists or .env.example is present"""
    print("\nTesting environment configuration...")
    if os.path.exists('.env'):
        print("✓ .env file exists")
        return True
    elif os.path.exists('.env.example'):
        print("⚠ .env.example exists but .env is missing")
        print("  Run: cp .env.example .env")
        print("  Then edit .env with your configuration")
        return True
    else:
        print("✗ No environment configuration found")
        return False


def test_scripts_executable():
    """Test that bash scripts are executable"""
    print("\nTesting script permissions...")
    scripts = [
        'scripts/run_vm_labs.sh',
        'scripts/vm_config.sh',
        'setup.sh'
    ]

    all_ok = True
    for script in scripts:
        if os.path.exists(script):
            if os.access(script, os.X_OK):
                print(f"✓ {script} is executable")
            else:
                print(f"✗ {script} is not executable")
                print(f"  Run: chmod +x {script}")
                all_ok = False
        else:
            print(f"⚠ {script} not found")

    return all_ok


def test_directory_structure():
    """Test that required directories exist or can be created"""
    print("\nTesting directory structure...")
    directories = [
        'scripts',
        'scripts/createlabs',
        'scripts/checklabs',
    ]

    all_ok = True
    for directory in directories:
        if os.path.exists(directory) and os.path.isdir(directory):
            print(f"✓ {directory}/ exists")
        else:
            print(f"✗ {directory}/ missing")
            all_ok = False

    # Check that runtime directories can be created
    runtime_dirs = ['completedLabs', 'logs', 'vm_configs']
    for directory in runtime_dirs:
        if not os.path.exists(directory):
            try:
                os.makedirs(directory)
                print(f"✓ Created {directory}/")
            except Exception as e:
                print(f"✗ Cannot create {directory}/: {e}")
                all_ok = False
        else:
            print(f"✓ {directory}/ exists")

    return all_ok


def test_app_initialization():
    """Test that Flask app can be initialized"""
    print("\nTesting Flask app initialization...")
    try:
        # Set test environment
        os.environ['DATABASE_URL'] = 'sqlite:///test.db'
        os.environ['SECRET_KEY'] = 'test-secret-key'

        from app import app
        app.config['TESTING'] = True

        with app.test_client() as client:
            # Test health endpoint
            response = client.get('/api/health')
            if response.status_code == 200:
                print("✓ Flask app initialized successfully")
                print(f"✓ Health check endpoint responding: {response.status_code}")
                return True
            else:
                print(f"✗ Health check failed: {response.status_code}")
                return False

    except Exception as e:
        print(f"✗ Flask app initialization failed: {e}")
        return False
    finally:
        # Cleanup test database
        if os.path.exists('test.db'):
            os.remove('test.db')


def test_grade_labs():
    """Test that grade_labs.py can run"""
    print("\nTesting grade_labs.py...")
    try:
        import subprocess
        result = subprocess.run(
            ['python3', 'grade_labs.py', '--help'],
            capture_output=True,
            text=True,
            timeout=5
        )

        if result.returncode == 0:
            print("✓ grade_labs.py can execute")
            return True
        else:
            print(f"✗ grade_labs.py failed: {result.stderr}")
            return False

    except Exception as e:
        print(f"✗ Error testing grade_labs.py: {e}")
        return False


def main():
    """Run all tests"""
    print("=" * 60)
    print("Lab Manager MVP - System Tests")
    print("=" * 60)

    tests = [
        ("Python Imports", test_imports),
        ("Environment Config", test_env_file),
        ("Script Permissions", test_scripts_executable),
        ("Directory Structure", test_directory_structure),
        ("Flask App Init", test_app_initialization),
        ("Grade Labs Script", test_grade_labs),
    ]

    results = []
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"\n✗ {test_name} crashed: {e}")
            results.append((test_name, False))

    # Summary
    print("\n" + "=" * 60)
    print("Test Summary")
    print("=" * 60)

    passed = sum(1 for _, result in results if result)
    total = len(results)

    for test_name, result in results:
        status = "PASS" if result else "FAIL"
        symbol = "✓" if result else "✗"
        print(f"{symbol} {test_name}: {status}")

    print(f"\nTotal: {passed}/{total} tests passed")

    if passed == total:
        print("\n🎉 All tests passed! System is ready.")
        return 0
    else:
        print("\n⚠️  Some tests failed. Please fix the issues above.")
        return 1


if __name__ == '__main__':
    sys.exit(main())
