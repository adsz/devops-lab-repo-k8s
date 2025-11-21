FROM nginx:alpine

# Copy static files
COPY --chmod=644 index.html /usr/share/nginx/html/
COPY --chmod=644 styles.css /usr/share/nginx/html/
COPY --chmod=644 app.js /usr/share/nginx/html/

# Copy nginx configuration
COPY --chmod=644 nginx.conf /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
