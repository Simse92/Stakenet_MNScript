#!/bin/bash

SCRIPTVER=1.0.0
COIN_NAME='XSN'
CONFIG_FILE='xsn.conf'
CONFIGFOLDER="$HOME/.xsncore"
COIN_BACKUP="$HOME/XSNBackup"
COIN_CLIENT='xsn-cli'
COIN_DAEMON='xsnd'
COIN_PORT=62583
#Updateable
COIN_GIT='https://github.com/X9Developers/XSN/releases/download/v1.0.14/xsn-1.0.14-linux64.tar.gz'
FILE_NAME_TAR='xsn-1.0.14-linux64.tar.gz'
FILE_NAME='xsn-1.0.14'

#Importand commands
ISSYNCED='mnsync status'
BLOCKCHAININFO='getblockchaininfo'


function doFullMasternode() {
  clear
  #installDependencies
  deleteOldInstallationAndBackup
  memorycheck
  enable_firewall
  downloadInstallNode
  coreConfiguration
  startXsnDaemon
  printInformationDuringSync
}

function installDependencies() {
    echo -e "Installing Dependencies"
    apt update #> /dev/null 2>&1
    #apt upgrade #> /dev/null 2>&1
    apt install -y ufw python virtualenv git unzip pv #> /dev/null 2>&1
}

function deleteOldInstallationAndBackup() {
  if [[ -f $( eval echo "$CONFIGFOLDER/wallet.dat" ) ]]; then
    echo -e "Found existing xsncore, making backup"

    if [[ ! -d $( eval echo "$COIN_BACKUP" ) ]]; then
      mkdir $( eval echo $COIN_BACKUP )
    fi

    cp $( eval echo $CONFIGFOLDER/xsn.conf $COIN_BACKUP ) #2> /dev/null
    cp $( eval echo $CONFIGFOLDER/wallet.dat $COIN_BACKUP ) #2> /dev/null

    #stop xsn-daemon
    $CONFIGFOLDER/$COIN_CLIENT stop #2> /dev/null

    #remove old ufw port
    ufw delete allow $COIN_PORT/tcp #>/dev/null 2>&1

  fi

  #remove old folder
  rm -rf $CONFIGFOLDER #> /dev/null 2>&1

  echo -e "Done";
}

function memorycheck() {

  echo -e "Checking Memory"
  FREEMEM=$( free -m |sed -n '2,2p' |awk '{ print $4 }' )
  SWAPS=$( free -m |tail -n1 |awk '{ print $2 }' )

  if [[ $FREEMEM -lt 2048 ]]; then
    if [[ $SWAPS -eq 0 ]]; then
      echo -e "Adding swap"
      fallocate -l 4G /swapfile
  		chmod 600 /swapfile
  		mkswap /swapfile
  		swapon /swapfile
  		cp /etc/fstab /etc/fstab.bak
  		echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

      echo -e "Added 4G Swapfile"
    else
      echo -e "Swapsize: $SWAPS, thats enough"
    fi
  else
    echo -e "Freemem: $FREEMEN, thats enough free ram"
  fi

}

function enable_firewall() {
  echo -e "Setting up firewall to allow traffic on port $COIN_PORT"
  ufw allow ssh/tcp #>/dev/null 2>&1
  ufw limit ssh/tcp #>/dev/null 2>&1
  ufw allow $COIN_PORT/tcp #>/dev/null 2>&1
  ufw logging on #>/dev/null 2>&1
  echo "y" | ufw enable #>/dev/null 2>&1
}

function downloadInstallNode() {
  echo -e "Downloading and Installing VPS XSN Daemon"

  if [[ ! -d $( eval echo "$CONFIGFOLDER" ) ]]; then
    mkdir $( eval echo $CONFIGFOLDER )
  fi

  wget $COIN_GIT #> /dev/null 2>&1
  tar xfvz $FILE_NAME_TAR  #> /dev/null 2>&1
  cp $FILE_NAME/bin/xsnd $CONFIGFOLDER #> /dev/null 2>&1
  cp $FILE_NAME/bin/xsn-cli $CONFIGFOLDER #> /dev/null 2>&1
  chmod 777 $CONFIGFOLDER/xsn*

  #Clean up
  rm -rf $FILE_NAME*
}

function coreConfiguration() {
  echo -e "Generating $COIN_NAME Config"

  RPCUSER=$(openssl rand -hex 11)
  RPCPASSWORD=$(openssl rand -hex 20)

  echo -e ""
  echo -e "We need some information: "
  echo -e "============================================================="
  echo -e "Enter your external VPS IPv4 adress"
  read -rp "Use the following scheme XXX.XXX.XXX.XXX: " VPSIP
  echo -e "============================================================="
  echo -e "Enter your $COIN_NAME Masternode GEN Key."
  echo -e "Please start your local wallet and go to"
  echo -e "Tools -> Debug Console and type masternode genkey"
  read -rp "Copy the string here: " MNKEY

cat << EOF > $(eval echo $CONFIGFOLDER/$CONFIG_FILE)

  #----
  rpcuser=$RPCUSER
  rpcpassword=$RPCPASSWORD
  rpcallowip=127.0.0.1
  #----
  listen=1
  server=1
  daemon=1
  maxconnections=264
  #----
  masternode=1
  masternodeprivkey=$MNKEY
  externalip=$VPSIP
  #----

EOF

  echo -e "Finished $CONFIG_FILE configuration"
}

function startXsnDaemon() {
  echo -e "Starting $COIN_NAME daemon"
  $CONFIGFOLDER/$COIN_DAEMON ##2> /dev/null

  #WaitOnServerStart
  waitWallet="-1"
  while [ $waitWallet -ne "0" ]
  do
    sleep 1
    2>/dev/null 1>/dev/null $CONFIGFOLDER/$COIN_CLIENT $BLOCKCHAININFO
    waitWallet="$?"
    echo -n "."
  done
  echo -e "Wallet up"
}

function waitSync() {
  syncStatus=$( ($CONFIGFOLDER/$COIN_CLIENT $ISSYNCED |grep 'IsSynced'|awk '{ print $2 }') )
}

function printInformationDuringSync() {
  syncStatus='false '
  while [ ! ${syncStatus::-1} = 'true' ]
  do
    actBlock=$( ($CONFIGFOLDER/$COIN_CLIENT $BLOCKCHAININFO |grep 'blocks'|awk '{ print $2 }') )
    maxBlock=$( ($CONFIGFOLDER/$COIN_CLIENT $BLOCKCHAININFO |grep 'headers'|awk '{ print $2 }') )

    echo -e "════════════════════════════"
    echo -e "SYNC"
    #echo -e "Time $"
    echo -e "Sync status: ${syncStatus::-1}"
    echo -e "Block progress: ${actBlock::-1}/${maxBlock::-1}"

    sleep 10
    syncStatus=$( ($CONFIGFOLDER/$COIN_CLIENT $ISSYNCED |grep 'IsSynced'|awk '{ print $2 }') )
  done
  echo -e "Sync finished!"
}


function getIP() {
  #foundAddr=$( eval ip addr | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
  #echo -e $foundAddr

  foundAddr="192.168.0.11.5.8.1"
  echo -e $foundAddr

  if [[ $foundAddr != "[[:space:]]+" ]]; then
    echo "string contains one more spaces"
  else
    echo "string doesn't contain spaces"
  fi

  echo -e "More than one IP address found"
  echo -e "Which one should be used?"

  select option in $foundAddr
  do
     case "$option" in
        End)  echo "End"; break ;;
          "")  echo "Invalid selection" ;;
           *)  echo "You have chosen $option!"
     esac
  done

  return $foundAddr
}

function checks() {
  if [[ $( lsb_release -d ) != *16.04* ]]; then
    echo -e "You are not running Ubuntu 16.04. Installation is cancelled."
    exit 1
  fi

  if [[ $EUID -ne 0 ]]; then
     echo -e "Must be run as root"
     exit 1
  fi
}

function showName() {
  echo -e "███████╗████████╗ █████╗ ██╗  ██╗███████╗███╗   ██╗███████╗████████╗"
  echo -e "██╔════╝╚══██╔══╝██╔══██╗██║ ██╔╝██╔════╝████╗  ██║██╔════╝╚══██╔══╝"
  echo -e "███████╗   ██║   ███████║█████╔╝ █████╗  ██╔██╗ ██║█████╗     ██║   "
  echo -e "╚════██║   ██║   ██╔══██║██╔═██╗ ██╔══╝  ██║╚██╗██║██╔══╝     ██║   "
  echo -e "███████║   ██║   ██║  ██║██║  ██╗███████╗██║ ╚████║███████╗   ██║   "
  echo -e "╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚══════╝   ╚═╝   "
}

function menu() {
  clear
  showName
  checks

  echo -e "Masternode script $SCRIPTVER"
  echo -e "════════════════════════════"
  echo -e "══════════ Menu ════════════"
  echo -e "════════════════════════════"

  echo -e "════════════════════════════"
  echo -e "1: Install full Masternode"
  echo -e "2: Update Masternode"
  echo -e "3: Exit"
  echo -e "════════════════════════════"

  #PS3="Ihre Wahl : "
  read -rp "Please select your choice: " opt
  case $opt in
    "1") echo -e "Install full Masternode"
         doFullMasternode
    ;;
    "2") echo -e "2"
    ;;
    "3") echo -e "3"
    ;;

    *) echo "invalid option";;
   esac
}

getIP
