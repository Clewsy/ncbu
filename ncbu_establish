#!/bin/bash

## An example docker run usage for creating an ncbu container.

##    --name	: Define a name for the container.
## -e --env	: Set an environment variable.
## -v --volume	: Define a volume (map internal to external directory).
## -d --detach	: Run container in background (detach).

docker run \
	--name nextcloud-bu_test \
	--env NEXTCLOUD_CONTAINER=nextcloud-app \
	--env NEXTCLOUD_DATABASE_CONTAINER=nextcloud-db \
	--env NEXTCLOUD_BACKUP_CRON="0 0 * * *" \
	--volume /etc/localtime:/etc/localtime:ro \
	--volume /var/run/docker.sock:/var/run/docker.sock:ro \
	--volume nextcloud-app:/mnt/nextcloud-app \
	--volume nextcloud-db:/mnt/nextcloud-db \
	--volume /home/docker/nextcloud-bu:/backup \
	--detach \
	clewsy/ncbu
