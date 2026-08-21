// vono Static File Server - JavaScript Example

console.log('🚀 vono Static File Server loaded!');

// Demonstrate dynamic content loading
document.addEventListener('DOMContentLoaded', function() {
    console.log('📄 DOM loaded successfully');
    
    //Add some interactive functions
    const features = document.querySelectorAll('.feature-list li');
    
    features.forEach((feature, index) => {
        feature.addEventListener('click', function() {
            this.style.transform = 'scale(1.05)';
            this.style.transition = 'transform 0.2s ease';
            
            setTimeout(() => {
                this.style.transform = 'scale(1)';
            }, 200);
            
            console.log(`✨ Feature ${index + 1} clicked: ${this.textContent}`);
        });
    });
    
    //Add timestamp
    const timestamp = new Date().toLocaleString('zh-CN');
    console.log(`⏰ Page loaded at: ${timestamp}`);
    
    // Check static file service status
    fetch('/api/status')
        .then(response => response.json())
        .then(data => {
            console.log('📊 Server status:', data);
        })
        .catch(error => {
            console.log('❌ Error fetching status:', error);
        });
});

// Utility function
function showMessage(message, type = 'info') {
    const colors = {
        info: '#4CAF50',
        warning: '#FF9800',
        error: '#F44336'
    };
    
    console.log(`%c${message}`, `color: ${colors[type]}; font-weight: bold;`);
}

// Export some tool functions for use by other scripts
window.VVonoUtils = {
    showMessage,
    getTimestamp: () => new Date().toISOString(),
    logFeature: (featureName) => showMessage(`Feature used: ${featureName}`, 'info')
}; 