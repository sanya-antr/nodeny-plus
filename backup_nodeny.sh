#!/bin/sh
PATH=/etc:/bin:/sbin:/usr/bin:/usr/sbin
passwd=`perl -e'require "/usr/local/nodeny/history.nod"; print "$sql_root_pass $sql_database";'`
mysql_cmd='/usr/local/bin/mysql'
mysqldump_cmd='/usr/local/bin/mysqldump'

file=`date "+%d-%m-%Y"`
cd /var/backups/
echo show tables | $mysql_cmd -u root --password=$passwd | \
    grep -v '^[ZX]2' | grep -v 'traflost' | grep -v '^Tables' | \
    xargs $mysqldump_cmd -R -Q --add-locks -u root --password=$passwd $1 > nodeny_${file}.sql
tar -c -z -f ${file}.tar.gz nodeny_${file}.sql
rm -f nodeny_${file}.sql
chmod 400 ${file}.tar.gz

find . -name "??-??-20??.tar.gz" -mtime +30 -type f -delete

