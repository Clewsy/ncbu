#! /bin/bash

## An example docker run usage for creating an ncbu container.

##    --name		: Define a name for the container.
## -t --tty		: Allocate a pseudo-tty.
## -i --interactive	: Keep stdin open even if not attached.
## -e --env		: Set an environment variable.
## -v --volume		: Define a volume (map internal to external directory).

docker run \
	--tty \
	--interactive \
	--name=nextcloud-bu \
	-env NEXTCLOUD_CONTAINER=nextcloud-app \		## Define the nextcloud app container name.
	-env NEXTCLOUD_DATABASE_CONTAINER=nextcloud-db \	## Define the nextcloud database container name.
	-env NEXTCLOUD_BACKUP_CRON="0 0 * * *" \		## Define the cronjob interval for running the backup script.
	-volume /etc/localtime:/etc/localtime:ro \		## Link the local time to the ncbu container so the cron job runs when expected.
	-volume /var/run/docker.sock:/var/run/docker.sock:ro \	## Link the docker.sock to enable docker commands to reach other containers.
	-volume nextcloud-app:/mnt/nextcloud-app \		## Define the nextcloud app volume for mounting within the ncbu container.
	-volume nextcloud-db:/mnt/nextcloud-db \		## Define the nextcloud database volume for mounting within the ncbu container.
	-volume ./nextcloud-bu:/backup \			## Define the user-accessible volume to which the physical backups will be stored.
	clewsy/ncbu						## The image to be used.
