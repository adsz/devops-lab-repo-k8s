// Configuration
const API_URL = window.location.hostname === 'localhost'
    ? 'http://localhost:5000'
    : `http://${window.location.hostname}:30050`;

// Load statistics
async function loadStats() {
    try {
        const response = await fetch(`${API_URL}/api/stats`);
        const data = await response.json();

        document.getElementById('totalPosts').textContent = data.posts;
        document.getElementById('totalComments').textContent = data.comments;
        document.getElementById('totalViews').textContent = data.total_views;
    } catch (error) {
        console.error('Error loading stats:', error);
    }
}

// Check API health
async function checkHealth() {
    try {
        const response = await fetch(`${API_URL}/health`);
        const data = await response.json();

        const statusEl = document.getElementById('apiStatus');
        if (data.status === 'healthy') {
            statusEl.textContent = '✅ Healthy';
            statusEl.style.color = 'green';
        } else {
            statusEl.textContent = '⚠️ Issues';
            statusEl.style.color = 'orange';
        }
    } catch (error) {
        document.getElementById('apiStatus').textContent = '❌ Down';
        document.getElementById('apiStatus').style.color = 'red';
    }
}

// Load posts
async function loadPosts() {
    try {
        const response = await fetch(`${API_URL}/api/posts`);
        const posts = await response.json();

        const postsList = document.getElementById('postsList');

        if (posts.length === 0) {
            postsList.innerHTML = '<p>No posts yet. Create one above!</p>';
            return;
        }

        postsList.innerHTML = posts.map(post => `
            <article class="post">
                <h3>${escapeHtml(post.title)}</h3>
                <p class="meta">By ${escapeHtml(post.author)} | ${formatDate(post.created_at)} | ${post.views} views</p>
                <p>${escapeHtml(post.content)}</p>
                <div class="post-actions">
                    <button onclick="viewPost(${post.id})">View Details</button>
                </div>
            </article>
        `).join('');
    } catch (error) {
        console.error('Error loading posts:', error);
        document.getElementById('postsList').innerHTML = '<p class="error">Error loading posts</p>';
    }
}

// Create post
document.getElementById('postForm').addEventListener('submit', async (e) => {
    e.preventDefault();

    const title = document.getElementById('postTitle').value;
    const author = document.getElementById('postAuthor').value;
    const content = document.getElementById('postContent').value;

    try {
        const response = await fetch(`${API_URL}/api/posts`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ title, author, content })
        });

        if (response.ok) {
            alert('Post created successfully!');
            document.getElementById('postForm').reset();
            loadPosts();
            loadStats();
        } else {
            alert('Error creating post');
        }
    } catch (error) {
        console.error('Error creating post:', error);
        alert('Error creating post');
    }
});

// View post details
async function viewPost(postId) {
    try {
        const response = await fetch(`${API_URL}/api/posts/${postId}`);
        const post = await response.json();

        alert(`Post Details:\n\nTitle: ${post.title}\nAuthor: ${post.author}\nViews: ${post.views}\n\n${post.content}`);
    } catch (error) {
        console.error('Error viewing post:', error);
    }
}

// Utility functions
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
}

// Event listeners
document.getElementById('refreshBtn').addEventListener('click', (e) => {
    e.preventDefault();
    loadPosts();
    loadStats();
    checkHealth();
});

// Initialize
checkHealth();
loadStats();
loadPosts();

// Refresh every 30 seconds
setInterval(() => {
    checkHealth();
    loadStats();
}, 30000);
