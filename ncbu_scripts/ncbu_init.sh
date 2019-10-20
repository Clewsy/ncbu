#! /bin/bash

TIMESTAMP () { date +%D-%T; }

echo
echo -e "$(TIMESTAMP) - Initialising ncbu (nextcloud-backup)..."

## Check environment variables defining nextcloud app and database were provided.
## Nextcloud app container required but the backup can proceed without the databse container.
echo -e "Checking environment variables provided:"
echo -e "NEXTCLOUD_CONTAINER=${NEXTCLOUD_CONTAINER}"
echo -e "NEXTCLOUD_DATABASE_CONTAINER=${NEXTCLOUD_DATABASE_CONTAINER}"
if [[ -z "${NEXTCLOUD_CONTAINER}" ]]; then
        echo -e "$(TIMESTAMP) - NEXTCLOUD_CONTAINER not provied.  Quitting"
        exit 1
fi

## Check volumes for the nextcloud and database were provided correctly.
## Nextcloud volume required but the backup can proceed without the databse volume.
echo -e "Checking mounted volumes:"
if [ ! -z "$(ls -A /mnt/nextcloud_app)" ]; then
        echo -e "Nextcloud app volume successfully mounted to /mnt/nextcloud_app"
else
        echo -e "Defined nextcloud app volume missing or empty.  Quitting"
        exit 1
fi

if [ ! -z "$(ls -A /mnt/nextcloud_db)" ]; then
        echo -e "Nextcloud database volume successfully mounted to /mnt/nextcloud_app"
fi

## Set the crontab to execute the backup script in accordanmce with the provided timing.
echo -e "Updating crontab with: \"${NEXTCLOUD_BACKUP_CRON} ncbu.sh\""
echo -e "${NEXTCLOUD_BACKUP_CRON} ncbu.sh" > /var/spool/cron/crontabs/root

## Run crond (i.e. all set, just waiting for the specified time to trigger the backup script.)
echo -e "$(TIMESTAMP) - Running crond in the foreground..."
crond -f
