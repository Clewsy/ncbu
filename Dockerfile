# Download base image: alpine linus
FROM alpine:latest

# Update and install additional packages
RUN	apk update && \
	apk add bash && \
	apk add docker && \
	apk add rsync

# Define the user for accessing the nextcloud container.  In default nextcloud installations this user is www-data.
ENV NEXTCLOUD_EXEC_USER=www-data

# Define the name of the nextcloud container.  No default is set - this must be set by the user.
ENV NEXTCLOUD_CONTAINER=
ENV NEXTCLOUD_DATABASE_CONTAINER=
ENV NEXTCLOUD_BACKUP_CRON="* * * * *"

# Create directories to be used by volumes.
RUN mkdir -p /backup/nextcloud_database
RUN mkdir -p /backup/nextcloud
RUN mkdir -p /mnt/nextcloud

# /mnt/nextcloud should be mounted to a directory on the host containing the nextcloud data
VOLUME /mnt/nextcloud

# /backup is the location in container to store the nextcloud data and database backups.
# Mount this volume to make it easily accessible from the host for off-site backups.
VOLUME /backup

# Copy the backup scripts into the container.
COPY ncbu_scripts /ncbu_scripts

ENTRYPOINT [ "/ncbu_scripts/ncbu_init.sh" ]

