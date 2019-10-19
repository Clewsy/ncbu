#! /bin/bash

TIMESTAMP="$(date +%D-%T)"

echo
echo -e "${TIMESTAMP} - Running ncbu (nextcloud backup)..."

## Put nextcloud into maintenance mode so that tall files and the database are locked.
echo -e "${TIMESTAMP} - Putting ${NEXTCLOUD_CONTAINER} into maintenance mode..."
docker exec -u ${NEXTCLOUD_EXEC_USER} ${NEXTCLOUD_CONTAINER} php occ maintenance:mode --on

## Sync the nextcloud app volume to the nextcloud-bu volume.
echo -e "${TIMESTAMP} - Nextcloud data backup: Syncing ${NEXTCLOUD_CONTAINER} volume to /backup..."
rsync --acls --archive --verbose --one-file-system --delete --human-readable --progress /mnt/nextcloud_app /backup/.
echo -e "${TIMESTAMP} - Finished nextcloud data sync."

##I f a database container was defined, sync the database volume to the nextcloud-bu volume.
if [[ -n "${NEXTCLOUD_DATABASE_CONTAINER}" ]]; then
        echo -e "${TIMESTAMP} - Nextcloud database backup (physical copy): Syncing ${NEXTCLOUD_DATABASE_CONTAINER} volume to /backup..."
        rsync --acls --archive --verbose --one-file-system --delete --human-readable --progress /mnt/nextcloud_db /backup/.
        echo -e "${TIMESTAMP} - Finished nextcloud database sync."
fi

##T ake nextcloud out of maintenance mode so that normal usage can resume.
echo -e "${TIMESTAMP} - Taking ${NEXTCLOUD_CONTAINER} out of maintenance mode..."
docker exec -u ${NEXTCLOUD_EXEC_USER} ${NEXTCLOUD_CONTAINER} php occ maintenance:mode --off
echo -e "${TIMESTAMP} - All done."
echo
