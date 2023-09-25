#!/bin/bash
echo "Démarrage du script de sauvegarde de Squash"
#############################################################################
# Nom du script     : squash-backup.sh
# Auteur            : E.RIEGEL (QM HENIX)
# Date de Création  : 24/02/2023
# Version           : 0.0.2
# Descritpion       : Script permettant la sauvegarde de la BDD de Squash
#
# Historique des mises à jour :
#-----------+--------+-------------+------------------------------------------------------
#  Version  |   Date   |   Auteur     |  Description
#-----------+--------+-------------+------------------------------------------------------
#  0.0.1    | 24/02/23 | E.RIEGEL     | Initialisation du script
#-----------+--------+-------------+------------------------------------------------------
#  0.0.2    | 21/09/23 | Y.ETRILLARD  | Ajout -task dans la commande nomad exec
#-----------+--------+-------------+------------------------------------------------------
#
###############################################################################################

. /root/.bash_profile

# Configuration de base: datestamp e.g. YYYYMMDD
DATE=$(date +"%Y%m%d")

# Dossier où sauvegarder les backups
BACKUP_DIR="/var/BACKUP/SQUASH"

# Commande NOMAD
#NOMAD=/usr/local/bin/nomad
NOMAD=$(which nomad)

#Name of the dump file (Bdd Rhodecode)
DUMP_FILENAME="BACKUP_SQUASH_BDD_${DATE}.dump"

# Nombre de jours à garder les dossiers (seront effacés après X jours)
RETENTION=3

# ---- NE RIEN MODIFIER SOUS CETTE LIGNE ------------------------------------------
#
# Create a new directory into backup directory location for this date
mkdir -p $BACKUP_DIR/$DATE

# Dump Squash bdd
echo "starting Squash dump..."
$NOMAD exec -task postgres -job forge-squashtm-postgresql  pg_dump -F c --dbname=postgresql://postgres@localhost/squashtm > $BACKUP_DIR/$DATE/$DUMP_FILENAME

DUMP_RESULT=$?
if [ $DUMP_RESULT -gt 0 ]
then
        echo "Squash dump failed with error code : ${DUMP_RESULT}"
        exit 1
else
        echo "Squash dump done"
fi

# Remove files older than X days
find $BACKUP_DIR/* -mtime +$RETENTION -exec rm -rf {} \;

echo "Backup Squash finished"
