// Global variables for DOM elements
let connectBtn, loadConfigBtn, deployBtn, proxmoxNode, storagePool;
let deploymentProgress, progressFill, progressPercentage, currentStep;
let deploymentLog, labVMs, vmGrid, connectionSection;

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    initializeDOMElements();
    addEventListeners();
    
    // Initialize with a log message
    setTimeout(() => {
        addLogMessage('RHCSA9 Lab Deployer initialized');
        addLogMessage('Please connect to your Proxmox server to begin');
    }, 500);
});

// Initialize DOM element references
function initializeDOMElements() {
    connectBtn = document.getElementById('connect-btn');
    loadConfigBtn = document.getElementById('load-config-btn');
    deployBtn = document.getElementById('deploy-btn');
    proxmoxNode = document.getElementById('proxmox-node');
    storagePool = document.getElementById('storage-pool');
    deploymentProgress = document.getElementById('deployment-progress');
    progressFill = document.getElementById('progress-fill');
    progressPercentage = document.getElementById('progress-percentage');
    currentStep = document.getElementById('current-step');
    deploymentLog = document.getElementById('deployment-log');
    labVMs = document.getElementById('lab-vms');
    vmGrid = document.getElementById('vm-grid');
    connectionSection = document.getElementById('connection-section');
}

// Add event listeners to buttons
function addEventListeners() {
    // Connect button
    connectBtn.addEventListener('click', connectToProxmox);
    
    // Load config button
    loadConfigBtn.addEventListener('click', loadConfigFromFile);
    
    // Deploy button
    deployBtn.addEventListener('click', startDeployment);
}

// Load configuration from file
function loadConfigFromFile() {
    // Fetch the config file
    fetch('config.json')
        .then(response => {
            if (!response.ok) {
                throw new Error('Config file not found or inaccessible');
            }
            return response.json();
        })
        .then(config => {
            // Populate form fields with config values
            document.getElementById('proxmox-host').value = config.proxmoxHost || '';
            document.getElementById('proxmox-token-id').value = config.tokenId || '';
            document.getElementById('proxmox-token-secret').value = config.tokenSecret || '';
            
            // Load default values for deployment form if available
            if (config.defaultNode) document.getElementById('proxmox-node').value = config.defaultNode;
            if (config.defaultStorage) document.getElementById('storage-pool').value = config.defaultStorage;
            if (config.defaultBridge) document.getElementById('network-bridge').value = config.defaultBridge;
            if (config.defaultPrefix) document.getElementById('vm-prefix').value = config.defaultPrefix;
            if (config.defaultIsoLocation) document.getElementById('iso-location').value = config.defaultIsoLocation;
            
            addLogMessage('Configuration loaded from config.json', 'success');
        })
        .catch(error => {
            addLogMessage('Error loading configuration: ' + error.message, 'error');
            alert('Failed to load configuration file. Please check the console for details.');
            console.error('Config loading error:', error);
        });
}

// Connect to Proxmox
function connectToProxmox() {
    const host = document.getElementById('proxmox-host').value;
    const tokenId = document.getElementById('proxmox-token-id').value;
    const tokenSecret = document.getElementById('proxmox-token-secret').value;
    
    if (!host || !tokenId || !tokenSecret) {
        alert('Please fill in all connection fields');
        return;
    }
    
    // Simulate connection to Proxmox
    connectBtn.disabled = true;
    connectBtn.textContent = 'Connecting...';
    
    setTimeout(() => {
        // Simulate successful connection
        connectBtn.textContent = 'Connected';
        connectBtn.classList.remove('btn-primary');
        connectBtn.classList.add('btn-success');
        
        // Enable deployment form
        deployBtn.disabled = false;
        proxmoxNode.disabled = false;
        storagePool.disabled = false;
        
        // Populate nodes and storage
        proxmoxNode.innerHTML = `
            <option value="pve">pve</option>
            <option value="pve2">pve2</option>
        `;
        
        storagePool.innerHTML = `
            <option value="local-lvm">local-lvm</option>
            <option value="local">local</option>
        `;
        
        addLogMessage('Successfully connected to Proxmox API at ' + host + ' using token ' + tokenId);
    }, 1500);
}

// Start deployment
function startDeployment() {
    const template = document.getElementById('lab-template').value;
    const node = proxmoxNode.value;
    const storage = storagePool.value;
    const bridge = document.getElementById('network-bridge').value;
    const prefix = document.getElementById('vm-prefix').value;
    const iso = document.getElementById('iso-location').value;
    
    if (!node || !storage || !bridge || !prefix || !iso) {
        alert('Please fill in all deployment fields');
        return;
    }
    
    // Start deployment
    deployBtn.disabled = true;
    deploymentProgress.style.display = 'block';
    
    // Add initial log message
    addLogMessage('Starting deployment of ' + template);
    addLogMessage('Using node: ' + node + ', storage: ' + storage + ', bridge: ' + bridge);
    
    // Simulate deployment steps
    simulateDeployment(template);
}

// Simulate deployment process
function simulateDeployment(template) {
    const steps = [
        'Creating VM templates...',
        'Downloading RHCSA9 configurations...',
        'Setting up network configuration...',
        'Creating server VM...',
        'Creating client VM(s)...',
        'Configuring boot options...',
        'Setting up console access...',
        'Finalizing deployment...'
    ];
    
    let currentStepIndex = 0;
    const totalSteps = steps.length;
    
    const interval = setInterval(() => {
        if (currentStepIndex >= totalSteps) {
            clearInterval(interval);
            finishDeployment(template);
            return;
        }
        
        currentStep.textContent = steps[currentStepIndex];
        addLogMessage(steps[currentStepIndex]);
        
        const progress = Math.round(((currentStepIndex + 1) / totalSteps) * 100);
        progressFill.style.width = `${progress}%`;
        progressPercentage.textContent = `${progress}%`;
        
        currentStepIndex++;
    }, 1500);
}

// Complete deployment and show VM list
function finishDeployment(template) {
    addLogMessage('Deployment completed successfully!', 'success');
    currentStep.textContent = 'Deployment completed';
    
    // Show VM list
    setTimeout(() => {
        labVMs.style.display = 'block';
        
        // Generate VM list based on template
        if (template === 'rhcsa9-base') {
            createVMCard('100', 'rhcsa9-server', 'running');
            createVMCard('101', 'rhcsa9-client', 'running');
        } else {
            createVMCard('100', 'rhcsa9-server', 'running');
            createVMCard('101', 'rhcsa9-client1', 'running');
            createVMCard('102', 'rhcsa9-client2', 'running');
        }
    }, 1000);
}

// Create VM card in the UI
function createVMCard(id, name, status) {
    const vmCard = document.createElement('div');
    vmCard.className = 'vm-card';
    
    const statusClass = status === 'running' ? 'status-running' : 'status-stopped';
    
    vmCard.innerHTML = `
        <div class="vm-header">
            <h4>${name}</h4>
            <div class="vm-status">
                <div class="status-dot ${statusClass}"></div>
                <span>${status}</span>
            </div>
        </div>
        <p><strong>ID:</strong> ${id}</p>
        <p><strong>CPU:</strong> 2 cores</p>
        <p><strong>Memory:</strong> 2 GB</p>
        <div class="vm-actions">
            <button class="btn btn-primary vm-console" data-id="${id}">Console</button>
            <button class="btn btn-success vm-start" data-id="${id}" ${status === 'running' ? 'disabled' : ''}>Start</button>
            <button class="btn btn-warning vm-stop" data-id="${id}" ${status === 'stopped' ? 'disabled' : ''}>Stop</button>
        </div>
    `;
    
    vmGrid.appendChild(vmCard);
    
    // Add console button handler
    vmCard.querySelector('.vm-console').addEventListener('click', function() {
        const vmId = this.getAttribute('data-id');
        openConsole(vmId, name);
    });
    
    // Add start button handler
    vmCard.querySelector('.vm-start').addEventListener('click', function() {
        const vmId = this.getAttribute('data-id');
        startVM(vmId, vmCard);
    });
    
    // Add stop button handler
    vmCard.querySelector('.vm-stop').addEventListener('click', function() {
        const vmId = this.getAttribute('data-id');
        stopVM(vmId, vmCard);
    });
}

// Open VM console
function openConsole(id, name) {
    const host = document.getElementById('proxmox-host').value;
    const consoleUrl = `${host}/console/?vmid=${id}&node=pve&console=kvm&novnc=1`;
    
    // In a real app, this would open the Proxmox console
    // For demo, just show an alert
    addLogMessage(`Opening console for ${name} (ID: ${id})`);
    alert(`Opening console for ${name}\n\nIn a production app, this would open: ${consoleUrl}`);
}

// Start VM
function startVM(id, vmCard) {
    addLogMessage(`Starting VM ${id}...`);
    
    // Update UI
    const statusDot = vmCard.querySelector('.status-dot');
    const statusText = vmCard.querySelector('.vm-status span');
    const startBtn = vmCard.querySelector('.vm-start');
    const stopBtn = vmCard.querySelector('.vm-stop');
    
    setTimeout(() => {
        statusDot.className = 'status-dot status-running';
        statusText.textContent = 'running';
        startBtn.disabled = true;
        stopBtn.disabled = false;
        addLogMessage(`VM ${id} started successfully`, 'success');
    }, 1000);
}

// Stop VM
function stopVM(id, vmCard) {
    addLogMessage(`Stopping VM ${id}...`);
    
    // Update UI
    const statusDot = vmCard.querySelector('.status-dot');
    const statusText = vmCard.querySelector('.vm-status span');
    const startBtn = vmCard.querySelector('.vm-start');
    const stopBtn = vmCard.querySelector('.vm-stop');
    
    setTimeout(() => {
        statusDot.className = 'status-dot status-stopped';
        statusText.textContent = 'stopped';
        startBtn.disabled = false;
        stopBtn.disabled = true;
        addLogMessage(`VM ${id} stopped successfully`, 'success');
    }, 1000);
}

// Add log message
function addLogMessage(message, type = 'info') {
    if (!deploymentLog) return; // Safety check
    
    const timestamp = new Date().toTimeString().split(' ')[0];
    const logEntry = document.createElement('div');
    logEntry.innerHTML = `<span style="color: #95a5a6;">[${timestamp}]</span> <span class="log-${type}">${message}</span>`;
    deploymentLog.appendChild(logEntry);
    deploymentLog.scrollTop = deploymentLog.scrollHeight;
}