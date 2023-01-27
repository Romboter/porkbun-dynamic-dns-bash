#!/usr/bin/env bash

crontab -l > additional_cron

echo "" >> additional_cron
echo "#DDNS" >> additional_cron
echo "*/5 * * * * bash $(pwd)/ddns.sh" >> additional_cron

#install new cron file
crontab additional_cron
rm additional_cron
