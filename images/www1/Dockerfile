
# Use the official Nginx image as a base image
FROM nginx:latest

# Copy the custom Nginx configuration file into the container
COPY ./nginx.conf /etc/nginx/nginx.conf

# Copy the static HTML content into the container
COPY ./html /usr/share/nginx/html

# Expose port 80 for the container
EXPOSE 80
