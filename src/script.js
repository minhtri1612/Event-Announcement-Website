// KHAI BÁO URL CỦA API Ở ĐẦU TỆP ĐỂ DỄ QUẢN LÝ
const API_URL = 'https://tsknykr0gi.execute-api.ap-southeast-2.amazonaws.com/dev';

// Form handling functions
function showMessage(elementId, show = true) {
    const element = document.getElementById(elementId);
    element.style.display = show ? 'block' : 'none';
}

function toggleLoading(formId, loading) {
    const form = document.getElementById(formId);
    const btn = form.querySelector('button[type="submit"]');
    const text = btn.querySelector('span');
    const spinner = btn.querySelector('.spinner');
    
    if (loading) {
        form.classList.add('loading');
        text.style.display = 'none';
        spinner.style.display = 'block';
    } else {
        form.classList.remove('loading');
        text.style.display = 'inline';
        spinner.style.display = 'none';
    }
}

// Event submission handler
document.getElementById('eventForm').addEventListener('submit', async function(e) {
    e.preventDefault();
    
    // Hide previous messages
    showMessage('submitSuccess', false);
    showMessage('submitError', false);
    
    // Show loading state
    toggleLoading('eventForm', true);
    
    // Get form data
    const formData = new FormData(this);
    const eventData = {
        title: formData.get('eventTitle'),
        date: formData.get('eventDate'),
        time: formData.get('eventTime'),
        location: formData.get('eventLocation'),
        category: formData.get('eventCategory'),
        description: formData.get('eventDescription'),
        organizerEmail: formData.get('organizerEmail'),
        submittedAt: new Date().toISOString()
    };
    
    try {
        // ĐÃ KÍCH HOẠT LỆNH GỌI API THẬT
        const response = await fetch(`${API_URL}/submit-event`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(eventData)
        });
        
        if (response.ok) {
            showMessage('submitSuccess', true);
            this.reset();
        } else {
            const errorData = await response.json();
            throw new Error(errorData.message || 'Submission failed');
        }
    } catch (error) {
        console.error('Error submitting event:', error);
        showMessage('submitError', true);
    } finally {
        toggleLoading('eventForm', false);
    }
});

// Subscription handler
document.getElementById('subscribeForm').addEventListener('submit', async function(e) {
    e.preventDefault();
    
    // Hide previous messages
    showMessage('subscribeSuccess', false);
    showMessage('subscribeError', false);
    
    // Show loading state
    toggleLoading('subscribeForm', true);
    
    // Get form data
    const formData = new FormData(this);
    const interests = Array.from(document.getElementById('interests').selectedOptions)
        .map(option => option.value);
    
    const subscriptionData = {
        name: formData.get('subscriberName'),
        email: formData.get('subscriberEmail'),
        interests: interests,
        subscribedAt: new Date().toISOString()
    };
    
    try {
        // ĐÃ KÍCH HOẠT LỆNH GỌI API THẬT
        const response = await fetch(`${API_URL}/subscribe`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(subscriptionData)
        });
        
        if (response.ok) {
            showMessage('subscribeSuccess', true);
            this.reset();
        } else {
            const errorData = await response.json();
            throw new Error(errorData.message || 'Subscription failed');
        }
    } catch (error) {
        console.error('Error subscribing:', error);
        showMessage('subscribeError', true);
    } finally {
        toggleLoading('subscribeForm', false);
    }
});

// Set minimum date to today
document.getElementById('eventDate').min = new Date().toISOString().split('T')[0];