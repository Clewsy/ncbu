#! /bin/bash

echo
echo -e "Initialising ncbu (nextcloud-backup)..."

echo -e "Checking environment variables provided:"
echo -e "NEXTCLOUD_CONTAINER=${NEXTCLOUD_CONTAINER}"
echo -e "NEXTCLOUD_DATABASE_CONTAINER=${NEXTCLOUD_DATABASE_CONTAINER}"
if [[ -z "${NEXTCLOUD_CONTAINER}" ]]; then
        echo -e "NEXTCLOUD_CONTAINER not provied.  Quitting"
        exit 1
fi

echo -e "Checking for required directories"
echo -e "(/backup/nextcloud and /backup/nextcloud_database will be created if absent)..."
if [ ! -d /backup/nextcloud ]; then  mkdir -p /backup/nextcloud; fi
if [ ! -d /backup/nextcloud_database ]; then  mkdir -p /backup/nextcloud_database; fi

echo -e "Updating crontab with: \"${NEXTCLOUD_BACKUP_CRON} /ncbu_scripts/ncbu.sh\""
echo -e "${NEXTCLOUD_BACKUP_CRON} /ncbu_scripts/ncbu.sh" > /var/spool/cron/crontabs/root

echo -e "Running crond in the foreground..."
crond -f
