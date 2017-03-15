#!/bin/bash

AUDITOR="automated";
DATE=$(date +%Y%m%d);
HOST=$(hostname);
LOG_DIR="/var/log/lynis";
REPORT="$LOG_DIR/report-${HOST}.${DATE}";
DATA="$LOG_DIR/report-data-${HOST}.${DATE}.txt";
DATELOG=$(date +%r);

RKHUNTER_INSTALL="true";
CHKROOTKIT_INSTALL="true";
CRON_INTERVAL=2; # hours
LOG_PATH="/var/log/.autosecure-${HOST}.${DATE}.log";
START_DATE=$(date -u);
LOG_COUNT=$(find "/var/log/autosecure/" -maxdepth 1 | wc -l);
CHKROOTKITLOG="/var/log/.chkrootkit-${HOST}.${DATE}.log";


# ---------------------------------------------- #

is_root() {
	if [ $EUID != 0 ] && [ $(whoami) != 'root' ]; then
	  echo -e "\033[1;91mError\033[1;00m: \033[1;94mroot silly\033[1;00m." && exit 2;
	fi 
}


# ---------------------------------------------- #

handle_logs() {
	if [ -d "/var/log/" ]; then
		if [ ! -d "/var/log/autosecure" ]; then
			echo -e "\033[1;91mNote\033[1;00m: \033[1;92mCreating Path For Auto Secure. ( var/log/autosecure )\033[1;00m";
			mkdir "/var/log/autosecure";
		else
		   if [ $LOG_COUNT -gt 10 ]; then	
				echo -e "\033[1;91mNote\033[1;00m: \033[1;92mCleaning Log(s) in /var/log/autosecure/ TOTAL FILES: $LOG_COUNT\033[1;00m";
				rm -f -v -r "/var/log/autosecure/*";
			fi
		fi
	fi
}

# ---------------------------------------------- #


log() {
  echo -e "\033[1;94m[$DATELOG]\033[1;00m: \033[1;92m$1\033[1;00m" && echo -e "[$DATE][$HOST >> $AUDITOR] $1" > $HOME/.autosecure.log;
}

# ---------------------------------------------- #

install_package() {
	is_installed=$(echo $(dpkg-query -W --showformat='${Status}\n' $1 | grep "install ok installed"));
	is_available=$(echo $(sudo apt-cache pkgnames | grep -x $1));
	if [ "$is_installed" == "" ] && [ "$is_available" != "" ]; then
		log "Building Dependencies for Package $1" && sudo apt-get build-dep $1;
		log "Installing Package $1" && sudo apt-get install $1 -y;
	fi
}


# ---------------------------------------------- #

cronjob_exist() {
   [[ $(echo $(crontab -l | grep "$1")) != "" ]] && echo "true" || echo "false";
}


# ---------------------------------------------- #


install_setup() {
	log "\n\n-------- STATS --------\nDATE=$START_DATE\nAUDITOR=$AUDITOR;\nHOST=$HOST\nLynis_Log=$LOG_DIR\nLynis_Report=$REPORT\nLynis_Data=$DATA\nUSE_RKHUNTER=$RKHUNTER_INSTALL\nUSE_CHKROOTKIT=$CHKROOTKIT_INSTALL\nCRON_INTERVAL=$CRON_INTERVAL\nLOG_PATH=$LOG_PATH\n-----------------------\n\n";
	log "Updating." && sudo apt-get update && install_package lynis;
	[ "$RKHUNTER_INSTALL" == "true" ] && install_package rkhunter;
	[ "$CHKROOTKIT_INSTALL" == "true" ] && install_package chkrootkit
}


# ---------------------------------------------- #


lynis_setup() {
   if [ -f "/usr/sbin/lynis" ]; then
		CDIR="$PWD";
		if [ $(cronjob_exist "lynis") == "true" ]; then
			log "[rkhunter] Cronjob already exist.";
		else
			log "[lynis] Found /usr/sbin/lynis" && log "[lynis] No crons! Installing new one";

			crontab -l > file;
			echo -e "* */$CRON_INTERVAL * * * /usr/sbin/lynis audit system --auditor "${AUDITOR}" --cronjob > ${REPORT}" >> file;
			crontab file;

			if [ -f "/var/log/lynis-report.dat" ]; then
			 log "[lynis] moving /var/log/lynis-report.dat to ${DATA}" && mv "/var/log/lynis-report.dat" ${DATA};
			fi

			log "[lynis] Saving lynis.pid" && echo $$ > "lynis.pid";
			log "[lynis] finished".
		fi
	fi
}

# ---------------------------------------------- #

rkhunter_setup() {
	if [ -f "/usr/bin/rkhunter" ]; then
		log "[rkhunter] Updating rkhunter.";

		sudo rkhunter --update && sudo rkhunter --propupd;

		log "[rkhunter] Check logs in /var/log/rkhunter.log";
		log "[rkhunter] Configuration file found in /etc/rkhunter.conf";
		log "[rkhunter] Finding existing crons."

		if [ $(cronjob_exist "rkhunter") == "true" ]; then
			log "[rkhunter] Cronjob already exist.";
		else
			log "[rkhunter] No crons! Installing new one.";

			crontab -l > file;
				echo -e "* */$CRON_INTERVAL * * * /usr/bin/rkhunter --cronjob --update --quiet" >> file; 
			crontab file;

			log "[rkhunter] Saving pid file.";
			echo $$ > "rkhunter.pid";
			log "[rkhunter] finished."
		fi
	fi
}


# ---------------------------------------------- #

chkrootkit_setup() {
	if [ -f "/usr/sbin/chkrootkit" ]; then
		chkrootkit -V;
		log "[chkrootkit] Checking for existing crons.";
		if [ $(cronjob_exist "chkrootkit") == "true" ]; then
			log "[chkrootkit] Cronjob already exist.";
		else
			log "[chkrootkit] No crons! Installing new one.";

			crontab -l > file;
				echo -e "* */$CRON_INTERVAL * * * /usr/sbin/chkrootkit 2>&1 | echo -e \"chkrootkit detected.\" >> $CHKROOTKITLOG )" >> file; 
			crontab file;

			log "[chkrootkit] Saving pid file.";
			echo $$ > "chkrootkit.pid";

			log "[chkrootkit] finished."
		fi
	fi
}

# ---------------------------------------------- #

log "Starting Script.";
handle_logs
install_setup
lynis_setup
rkhunter_setup
chkrootkit_setup
log "Script is finished."
