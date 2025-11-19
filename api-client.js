/**
 * API Client for Lab Manager
 * Handles all API communication with the backend
 */

class LabManagerAPI {
    constructor(baseURL = '') {
        this.baseURL = baseURL || window.location.origin;
        this.currentUser = null;
    }

    /**
     * Make API request with error handling
     */
    async request(endpoint, options = {}) {
        const url = `${this.baseURL}${endpoint}`;
        const defaultOptions = {
            headers: {
                'Content-Type': 'application/json',
            },
            credentials: 'include', // Include cookies for session management
        };

        const config = { ...defaultOptions, ...options };

        try {
            const response = await fetch(url, config);
            const data = await response.json();

            if (!response.ok) {
                throw new Error(data.error || `HTTP error! status: ${response.status}`);
            }

            return data;
        } catch (error) {
            console.error(`API request failed: ${endpoint}`, error);
            throw error;
        }
    }

    // ========================================================================
    // Authentication
    // ========================================================================

    async login(username, password) {
        const data = await this.request('/api/auth/login', {
            method: 'POST',
            body: JSON.stringify({ username, password }),
        });
        this.currentUser = data.user;
        return data;
    }

    async logout() {
        const data = await this.request('/api/auth/logout', {
            method: 'POST',
        });
        this.currentUser = null;
        return data;
    }

    async checkAuthStatus() {
        const data = await this.request('/api/auth/status');
        if (data.authenticated) {
            this.currentUser = data.user;
        }
        return data;
    }

    // ========================================================================
    // Proxmox Operations
    // ========================================================================

    async connectToProxmox(host, tokenId, tokenSecret) {
        return await this.request('/api/proxmox/connect', {
            method: 'POST',
            body: JSON.stringify({
                host,
                token_id: tokenId,
                token_secret: tokenSecret,
            }),
        });
    }

    async getProxmoxNodes() {
        return await this.request('/api/proxmox/nodes');
    }

    async getStorage(node) {
        return await this.request(`/api/proxmox/storage?node=${encodeURIComponent(node)}`);
    }

    // ========================================================================
    // Deployments
    // ========================================================================

    async createDeployment(template, node, storage, bridge, prefix, isoLocation) {
        return await this.request('/api/deployments', {
            method: 'POST',
            body: JSON.stringify({
                template,
                node,
                storage,
                bridge,
                prefix,
                iso_location: isoLocation,
            }),
        });
    }

    async listDeployments(page = 1, perPage = 20) {
        return await this.request(`/api/deployments?page=${page}&per_page=${perPage}`);
    }

    async getDeployment(deploymentId) {
        return await this.request(`/api/deployments/${deploymentId}`);
    }

    // ========================================================================
    // Lab Results
    // ========================================================================

    async listResults(page = 1, perPage = 20) {
        return await this.request(`/api/results?page=${page}&per_page=${perPage}`);
    }

    // ========================================================================
    // Configuration
    // ========================================================================

    async getConfig() {
        return await this.request('/api/config');
    }

    // ========================================================================
    // Health Check
    // ========================================================================

    async healthCheck() {
        return await this.request('/api/health');
    }
}

// Export for use in other scripts
if (typeof module !== 'undefined' && module.exports) {
    module.exports = LabManagerAPI;
}
