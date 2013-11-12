#!/bin/bash
#
# corosync-backup-script.sh
#
# Features:
# - Create 2 backups files (plain & xml formats) of corosync configs on specified directory.
# - Purge old backups aftef X days on specified directory (optional)
# - Alert by email on errors.
#
#  Set a cron task to run it:
#
#  # Corosync backups
#  00 03 * * * /usr/local/sbin/corosync-backup.sh 1>/dev/null 2>/dev/null
#

# On errors, alert to..
ALERTTO="alerts@email"

# Delete old backups? (more that 10 days) (yes/no)
DELETEOLD="yes"

# Corosync crm binary path
CRM_BIN_PATH="/usr/sbin/crm"

if [ $# -ne 1 ]
then
	echo -e "\nUsage: ./`basename $0` <backups-dir>\n\nExample: ./`basename $0` /opt/backups"
	echo -e "\nWill create 2 backups files (plain & xml) on /opt/backups/ directory.\n"
	exit 1
fi

DATE=$(date +%Y-%m-%d-%H%M%S)
HOSTNAME=`hostname`
BKPDIR="$1"
BKPFILE1="$BKPDIR/corosync-$HOSTNAME.$DATE.bkp"
BKPFILE2="$BKPDIR/corosync-$HOSTNAME.$DATE.xml"
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

function chkFile() {
	FILE="$1"
	if [ -s "$FILE" ];
	then
		echo "- Verification: $FILE - OK"
	else
		echo "- Verification: $FILE - ERROR"
		echo "  Sending alert to $ALERTTO..."
		sendEmail "$ALERTTO" "$ALERTTO" "ERROR on corosync backup for $HOSTNAME" "Corosync Backup fail on $HOSTNAME - The file $FILE is EMPTY."
	fi
}

function sendEmail() {
	TO_ADDRESS="$1"
	SUBJECT="$2"
	BODY="$3"
	echo -e ${BODY}| mail -s "${SUBJECT}" ${TO_ADDRESS}
}

function purgeOldBackups() {
	BKPDIR="$1"
	echo "- Purging old backups on $BKPDIR ..."
	for filename in $( nice -20 find $BKPDIR -type f -mtime +10) ; do rm -f "$filename"; done 
}

if [ ! -d "$BKPDIR" ]; then
	echo "- Directory ${BKPDIR} doesn't exist. Creating..."
	mkdir ${BKPDIR}
fi

if [ -x ${CRM_BIN_PATH} ]; then
	echo "- Binary ${CRM_BIN_PATH} OK"
	echo "- Creating backup (plain): $BKPFILE1"
	${CRM_BIN_PATH} configure save $BKPFILE1
	gzip $BKPFILE1
	chkFile "$BKPFILE1.gz"
	echo "- Creating backup (xml): $BKPFILE2"
	${CRM_BIN_PATH} configure save xml $BKPFILE2
        gzip $BKPFILE2
	chkFile "$BKPFILE2.gz"
	if [ "${DELETEOLD}" = "yes" ]; then
		purgeOldBackups "$BKPDIR"
	fi
else
	echo "- Fatal error: ${CRM_BIN_PATH} does not exist."
	echo "  Sending alert to $ALERTTO..."
	sendEmail "$ALERTTO" "ERROR on corosync backup for $HOSTNAME" "Corosync Backup fail on $HOSTNAME - ${CRM_BIN_PATH} does not exist."
	exit 1
fi
