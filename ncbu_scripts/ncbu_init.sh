#! /bin/bash

## This script is the entry point for the ncbu container.
## It does some basic error checkings, sets up the cronjob then initiates crond in the foreground.

TIMESTAMP () { date +%Y-%m-%d\ %T; }

echo
echo -e "$(TIMESTAMP) - Initialising ncbu (nextcloud-backup)..."

## Check environment variables defining nextcloud app and database were provided.
## Nextcloud app container required but the backup can proceed without the database container.
echo -e "Checking environment variables provided:"
echo -e "NEXTCLOUD_CONTAINER=${NEXTCLOUD_CONTAINER}"
echo -e "NEXTCLOUD_DATABASE_CONTAINER=${NEXTCLOUD_DATABASE_CONTAINER}"
if [[ -z "${NEXTCLOUD_CONTAINER}" ]]; then
        echo -e "$(TIMESTAMP) - NEXTCLOUD_CONTAINER not provied.  Quitting"
        exit 1
fi

## Check volumes for the nextcloud and database were provided correctly.
## Nextcloud volume required but the backup can proceed without the database volume.
echo -e "Checking mounted volumes:"
if [ -n "$(ls -A /mnt/nextcloud_app)" ];        then echo -e "Nextcloud app volume successfully mounted to /mnt/nextcloud_app"
                                                else echo -e "Nextcloud app volume missing, empty or not defined."; fi

if [ -n "$(ls -A /mnt/nextcloud_db)" ];         then echo -e "Nextcloud database volume successfully mounted to /mnt/nextcloud_db"
                                                else echo -e "Nextcloud database volume missing, empty or not defined."; fi

## Set the crontab to execute the backup script in accordance with the provided timing.
echo -e "Updating crontab with: \"${NEXTCLOUD_BACKUP_CRON} ncbu.sh\""
echo -e "${NEXTCLOUD_BACKUP_CRON} ncbu.sh" > /var/spool/cron/crontabs/root

## Run crond (i.e. all set, just waiting for the specified time to trigger the backup script.)
echo -e "$(TIMESTAMP) - Running crond in the foreground..."
crond -f
