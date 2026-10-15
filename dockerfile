FROM nginx:alpine

LABEL maintainer="University Placement Cell"
LABEL application="Student Placement Portal"

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80