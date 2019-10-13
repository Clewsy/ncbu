#! /bin/bash

echo
echo -e "Running ncbu (nextcloud backup)..."

echo -e "Putting ${NEXTCLOUD_CONTAINER} into maintenance mode..."
docker exec -u ${NEXTCLOUD_EXEC_USER} ${NEXTCLOUD_CONTAINER} php occ maintenance:mode --on

echo -e "Copying ${NEXTCLOUD_CONTAINER} data to /backup..."
rsync --acls --archive --verbose --one-file-system --delete --human-readable --progress /mnt/nextcloud /backup/.
echo -e "Finished nextcloud data backup."

if [[ -n "${NEXTCLOUD_DATABASE_CONTAINER}" ]]; then
        echo -e "Copying nextcloud database (physical backup) from ${NEXTCLOUD_DATABASE_CONTAINER}..."
        docker cp --archive ${NEXTCLOUD_DATABASE_CONTAINER}:/var/lib/mysql /backup/nextcloud_database/.
        echo -e "Finished nextcloud database backup."
fi

echo -e "Taking ${NEXTCLOUD_CONTAINER} out of maintenance mode..."
docker exec -u ${NEXTCLOUD_EXEC_USER} ${NEXTCLOUD_CONTAINER} php occ maintenance:mode --off
echo -e "All done."
echo
