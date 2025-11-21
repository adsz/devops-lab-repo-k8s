#!/usr/bin/env python3
"""
Simple Blog API - Flask REST API
"""
from flask import Flask, jsonify, request
from flask_cors import CORS
import psycopg2
import redis
import os
from datetime import datetime

app = Flask(__name__)
CORS(app)

# Config from environment
DB_HOST = os.getenv('DB_HOST', 'blog-db')
DB_NAME = os.getenv('DB_NAME', 'blogdb')
DB_USER = os.getenv('DB_USER', 'blog')
DB_PASS = os.getenv('DB_PASS', 'blogpass')

REDIS_HOST = os.getenv('REDIS_HOST', 'blog-cache')
REDIS_PORT = int(os.getenv('REDIS_PORT', '6379'))

# Database connection
def get_db():
    return psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASS
    )

# Redis connection
def get_redis():
    return redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)

# Initialize database
def init_db():
    conn = get_db()
    cur = conn.cursor()

    # Create tables
    cur.execute('''
        CREATE TABLE IF NOT EXISTS posts (
            id SERIAL PRIMARY KEY,
            title VARCHAR(200) NOT NULL,
            content TEXT NOT NULL,
            author VARCHAR(100) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            views INT DEFAULT 0
        )
    ''')

    cur.execute('''
        CREATE TABLE IF NOT EXISTS comments (
            id SERIAL PRIMARY KEY,
            post_id INT REFERENCES posts(id) ON DELETE CASCADE,
            author VARCHAR(100) NOT NULL,
            content TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')

    conn.commit()
    cur.close()
    conn.close()

# Routes
@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    try:
        # Check DB
        conn = get_db()
        conn.close()
        db_status = 'ok'
    except:
        db_status = 'error'

    try:
        # Check Redis
        r = get_redis()
        r.ping()
        redis_status = 'ok'
    except:
        redis_status = 'error'

    status = 'healthy' if db_status == 'ok' and redis_status == 'ok' else 'unhealthy'

    return jsonify({
        'status': status,
        'timestamp': datetime.utcnow().isoformat(),
        'checks': {
            'database': db_status,
            'redis': redis_status
        }
    })

@app.route('/ready', methods=['GET'])
def ready():
    """Readiness probe"""
    try:
        conn = get_db()
        conn.close()
        return jsonify({'ready': True})
    except:
        return jsonify({'ready': False}), 503

@app.route('/api/posts', methods=['GET'])
def get_posts():
    """Get all posts"""
    try:
        # Check cache
        r = get_redis()
        cached = r.get('posts:all')
        if cached:
            import json
            return jsonify(json.loads(cached))

        # Query database
        conn = get_db()
        cur = conn.cursor()
        cur.execute('SELECT id, title, content, author, created_at, views FROM posts ORDER BY created_at DESC')
        posts = []
        for row in cur.fetchall():
            posts.append({
                'id': row[0],
                'title': row[1],
                'content': row[2],
                'author': row[3],
                'created_at': row[4].isoformat(),
                'views': row[5]
            })
        cur.close()
        conn.close()

        # Cache result
        import json
        r.setex('posts:all', 60, json.dumps(posts))

        return jsonify(posts)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/posts/<int:post_id>', methods=['GET'])
def get_post(post_id):
    """Get single post"""
    try:
        conn = get_db()
        cur = conn.cursor()

        # Increment views
        cur.execute('UPDATE posts SET views = views + 1 WHERE id = %s', (post_id,))

        # Get post
        cur.execute('SELECT id, title, content, author, created_at, views FROM posts WHERE id = %s', (post_id,))
        row = cur.fetchone()

        if not row:
            return jsonify({'error': 'Post not found'}), 404

        post = {
            'id': row[0],
            'title': row[1],
            'content': row[2],
            'author': row[3],
            'created_at': row[4].isoformat(),
            'views': row[5]
        }

        conn.commit()
        cur.close()
        conn.close()

        return jsonify(post)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/posts', methods=['POST'])
def create_post():
    """Create new post"""
    try:
        data = request.json
        title = data.get('title')
        content = data.get('content')
        author = data.get('author', 'Anonymous')

        if not title or not content:
            return jsonify({'error': 'Title and content required'}), 400

        conn = get_db()
        cur = conn.cursor()
        cur.execute(
            'INSERT INTO posts (title, content, author) VALUES (%s, %s, %s) RETURNING id',
            (title, content, author)
        )
        post_id = cur.fetchone()[0]
        conn.commit()
        cur.close()
        conn.close()

        # Clear cache
        r = get_redis()
        r.delete('posts:all')

        return jsonify({'id': post_id, 'message': 'Post created'}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/posts/<int:post_id>/comments', methods=['GET'])
def get_comments(post_id):
    """Get comments for post"""
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute('SELECT id, author, content, created_at FROM comments WHERE post_id = %s ORDER BY created_at', (post_id,))
        comments = []
        for row in cur.fetchall():
            comments.append({
                'id': row[0],
                'author': row[1],
                'content': row[2],
                'created_at': row[3].isoformat()
            })
        cur.close()
        conn.close()
        return jsonify(comments)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/posts/<int:post_id>/comments', methods=['POST'])
def add_comment(post_id):
    """Add comment to post"""
    try:
        data = request.json
        author = data.get('author', 'Anonymous')
        content = data.get('content')

        if not content:
            return jsonify({'error': 'Content required'}), 400

        conn = get_db()
        cur = conn.cursor()
        cur.execute(
            'INSERT INTO comments (post_id, author, content) VALUES (%s, %s, %s) RETURNING id',
            (post_id, author, content)
        )
        comment_id = cur.fetchone()[0]
        conn.commit()
        cur.close()
        conn.close()

        return jsonify({'id': comment_id, 'message': 'Comment added'}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/stats', methods=['GET'])
def stats():
    """Get system statistics"""
    try:
        conn = get_db()
        cur = conn.cursor()

        cur.execute('SELECT COUNT(*) FROM posts')
        post_count = cur.fetchone()[0]

        cur.execute('SELECT COUNT(*) FROM comments')
        comment_count = cur.fetchone()[0]

        cur.execute('SELECT SUM(views) FROM posts')
        total_views = cur.fetchone()[0] or 0

        cur.close()
        conn.close()

        r = get_redis()
        cache_keys = len(r.keys('*'))

        return jsonify({
            'posts': post_count,
            'comments': comment_count,
            'total_views': total_views,
            'cache_keys': cache_keys
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Initialize database on module import (works with gunicorn)
try:
    init_db()
    print("Database initialized")
except Exception as e:
    print(f"Database init error: {e}")

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
