#!/bin/bash

#Debug
#COIN_GIT='https://github.com/X9Developers/XSN/releases/download/v1.0.13/xsn-1.0.13-linux64.tar.gz'
#FILE_NAME_TAR='xsn-1.0.13-linux64.tar.gz'
#FILE_NAME='xsn-1.0.13'

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
WALLET_VER='1001400'

BOOTSTRAP_LINK='https://github.com/X9Developers/XSN/releases/download/v1.0.13/bootstrap.dat.zip'
BOOTSTRAP_ZIP_NAME='bootstrap.dat.zip'
BOOTSTRAP_FILE_NAME='bootstrap.dat'

#Importand commands
ISSYNCED='mnsync status'
BLOCKCHAININFO='getblockchaininfo'
NETWORKINFO='getnetworkinfo'
WALLETINFO='getwalletinfo'
GREENTICK='\033[0;32m\xE2\x9C\x94\033[0m'
CURSOR_PREVIOUS_LINE='\033[1A'

#Global variables
NODE_IP=""
WALLET_TIMEOUT_S=45   #Test showed that the wallet is up after 40 seconds

function doFullMasternode() {
  clear
  #installDependencies
  deleteOldInstallationAndBackup
  memorycheck
  enable_firewall
  downloadInstallNode
  coreConfiguration
  #addBootstrap
  startXsnDaemon
  printInformationDuringSync
}

function doUpdateMasternode {
  clear
  backupData

  if  [[ $? -ne 1 ]]; then
    checkWalletVersion
    stopAndDelOldDaemon
    downloadInstallNode
    recoverBackup
    #addBootstrap
    startXsnDaemon
    printInformationDuringSync
  else
    menu
  fi
}

function backupData() {
  if [[ -f $( eval echo "$CONFIGFOLDER/wallet.dat" ) ]]; then
    echo -e "Found existing xsncore, making backup"

    if [[ ! -d $( eval echo "$COIN_BACKUP" ) ]]; then
      mkdir $( eval echo $COIN_BACKUP )
    fi

    cp $( eval echo $CONFIGFOLDER/xsn.conf $COIN_BACKUP ) 2> /dev/null
    cp $( eval echo $CONFIGFOLDER/wallet.dat $COIN_BACKUP ) 2> /dev/null

  else
    #Fancy blink blink
    echo -e "No $COIN_NAME install found"
    echo -e "Do you want a full Masternode install?"
    echo -e ""
    return 1
  fi
}

function checkWalletVersion() {

  wasStarted=0
  if [[ -z "$(ps axo cmd:100 | egrep $COIN_DAEMON | grep ^[^grep])" ]]; then
    echo -e "Starting daemon to check version.."
    wasStarted=1
    startXsnDaemon
  fi

  walletVersion=$( ($CONFIGFOLDER/$COIN_CLIENT $NETWORKINFO |grep -m1 'version'|awk '{ print $2 }') )

  if [[ $wasStarted = 1 ]]; then
    echo -e "Shutting daemon down again"
    $CONFIGFOLDER/$COIN_CLIENT stop
  fi

  if [[ ${walletVersion::-1} = $WALLET_VER ]]; then
    echo -e "You are already running the latest XSN-Core.."
    exit
  fi

  echo -e "Starting Update"
}

function stopAndDelOldDaemon() {
  #stop xsn-daemon
  stopDaemon
  rm -rf $CONFIGFOLDER/$COIN_CLIENT #> /dev/null 2>&1
  rm -rf $CONFIGFOLDER/$COIN_DAEMON #> /dev/null 2>&1
}

function recoverBackup() {
  cp $( eval echo $COIN_BACKUP/xsn.conf $CONFIGFOLDER ) #2> /dev/null
  cp $( eval echo $COIN_BACKUP/wallet.dat $CONFIGFOLDER ) #2> /dev/null
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
    stopDaemon

    #remove old ufw port
    ufw delete allow $COIN_PORT/tcp >/dev/null 2>&1

  fi

  #remove old folder
  rm -rf $CONFIGFOLDER #> /dev/null 2>&1
}

function stopDaemon() {
  if [[ ! -z "$(ps axo cmd:100 | egrep $COIN_DAEMON | grep ^[^grep])" ]]; then
    $CONFIGFOLDER/$COIN_CLIENT stop #2> /dev/null

    while [[ -z "$(ps axo cmd:100 | egrep $COIN_DAEMON | grep ^[^grep])" ]]
    do
      sleep 1
    done
  fi
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
  ufw allow ssh/tcp >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw allow $COIN_PORT/tcp >/dev/null 2>&1
  ufw logging on >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
}

#From https://stackoverflow.com/questions/4686464/how-to-show-wget-progress-bar-only
function progressfilt ()
{
    local flag=false c count cr=$'\r' nl=$'\n'
    while IFS='' read -d '' -rn 1 c
    do
        if $flag
        then
            printf '%c' "$c"
        else
            if [[ $c != $cr && $c != $nl ]]
            then
                count=0
            else
                ((count++))
                if ((count > 1))
                then
                    flag=true
                fi
            fi
        fi
    done
}

function downloadInstallNode() {
  echo -e "Downloading and Installing VPS XSN Daemon"

  if [[ ! -d $( eval echo "$CONFIGFOLDER" ) ]]; then
    mkdir $( eval echo $CONFIGFOLDER )
  fi

  wget --progress=bar:force $COIN_GIT 2>&1 | progressfilt
  if [ $? -ne 0 ]
  then
    echo -e "Failed to download $COIN_GIT"
    exit
  fi

  tar xfvz $FILE_NAME_TAR  > /dev/null 2>&1
  if [ $? -ne 0 ]
  then
    echo -e "Failed to unzip $FILE_NAME_TAR"
    exit
  fi

  cp $FILE_NAME/bin/xsnd $CONFIGFOLDER > /dev/null 2>&1
  cp $FILE_NAME/bin/xsn-cli $CONFIGFOLDER > /dev/null 2>&1
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
  echo -e "Enter your $COIN_NAME Masternode GEN Key."
  echo -e "Please start your local wallet and go to"
  echo -e "Tools -> Debug Console and type masternode genkey"
  read -rp "Copy the string here: " MNKEY
  echo -e "============================================================="
  #echo -e "Enter your external VPS IPv4 adress"
  #read -rp "Use the following scheme XXX.XXX.XXX.XXX: " VPSIP
  getIP
  echo -e "Using IP Address $NODE_IP"

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
  externalip=$NODE_IP
  #----

EOF

  echo -e "Finished $CONFIG_FILE configuration"
}

function startXsnDaemon() {
  echo -e "Starting $COIN_NAME daemon (takes up to $WALLET_TIMEOUT_S seconds)"
  $CONFIGFOLDER/$COIN_DAEMON ##2> /dev/null

  #WaitOnServerStart
  waitWallet="-1"
  retryCounter=0
  echo -ne "Waiting on wallet"
  while [[ $waitWallet -ne "0" && $retryCounter -lt $WALLET_TIMEOUT_S ]]
  do
    sleep 1
    2>/dev/null 1>/dev/null $CONFIGFOLDER/$COIN_CLIENT $BLOCKCHAININFO
    waitWallet="$?"
    retryCounter=$[retryCounter+1]
    echo -ne "."
  done

  echo ""
  if [[ $retryCounter -ge $WALLET_TIMEOUT_S ]]; then
    echo -e "Error during wallet startup"
    printErrorLog
    exit
  else
    echo -e "Wallet startup successful"
  fi
}

function printInformationDuringSync() {
  syncStatus='false '
  bcSyncStatus='false '
  mnlSyncStatus='false '
  wlSyncStatus='false '
  while [ ! ${syncStatus::-1} = 'true' ]
  do
    actBlock=$( ($CONFIGFOLDER/$COIN_CLIENT $BLOCKCHAININFO |grep 'blocks'|awk '{ print $2 }') )
    maxBlock=$( ($CONFIGFOLDER/$COIN_CLIENT $BLOCKCHAININFO |grep 'headers'|awk '{ print $2 }') )
    numCon=$( ($CONFIGFOLDER/$COIN_CLIENT $NETWORKINFO |grep 'connections'|awk '{ print $2 }') )

    echo -ne "═══════════════════════════
Synchronisation Time: $(date)

Number of connections: ${numCon::-1}
Block progress: ${actBlock::-1}/${maxBlock::-1}

Blockchain Sync status: ${bcSyncStatus::-1}
Masternode Sync status: ${mnlSyncStatus::-1}
Winners list Sync status: ${wlSyncStatus::-1}

Sync status: ${syncStatus::-1}
═══════════════════════════"\\033[11A\\r

    sleep 1
    syncStatus=$( ($CONFIGFOLDER/$COIN_CLIENT $ISSYNCED |grep 'IsSynced'|awk '{ print $2 }') )
    bcSyncStatus=$( ($CONFIGFOLDER/$COIN_CLIENT $ISSYNCED |grep 'IsBlockchainSynced'|awk '{ print $2 }') )
    mnlSyncStatus=$( ($CONFIGFOLDER/$COIN_CLIENT $ISSYNCED |grep 'IsMasternodeListSynced'|awk '{ print $2 }') )
    wlSyncStatus=$( ($CONFIGFOLDER/$COIN_CLIENT $ISSYNCED |grep 'IsWinnersListSynced'|awk '{ print $2 }') )
  done
  echo -e "$GREENTICK Sync finished!"
}

function printErrorLog() {
  error=$( (cat $CONFIGFOLDER/debug.log |grep Error) )
  echo -e "$error"
}


function getIP() {
  foundAddr=$( eval ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')

  if [[ "$foundAddr" = *$'\n'* ]]; then
    echo -e "More than one IP address found"
    echo -e "Select the one you want to use"

    select option in $foundAddr
    do
       case "$option" in
          End)  echo "End"; break ;;
            "")  echo "Invalid selection" ;;
             *)  NODE_IP="$option"
                 break
       esac
    done
  else
      echo "Found IP Address $foundAddr"
      NODE_IP="$foundAddr"
  fi
}

function checkBootstrap() {
  if [ -f $CONFIGFOLDER/$BOOTSTRAP_FILE_NAME* ]
  then
    echo -e "Bootstrap already installed"
    return 0
  else
    echo -e "Bootstrap not found"
    return 1
  fi
}

function installBootstrap() {
  wget --progress=bar:force $BOOTSTRAP_LINK 2>&1 | progressfilt
  if [ $? -ne 0 ]
  then
    echo -e "Failed to download $BOOTSTRAP_FILE_NAME"
  else
    unzip -j $BOOTSTRAP_ZIP_NAME* $BOOTSTRAP_FILE_NAME -d $CONFIGFOLDER
    if [ $? -ne 0 ]
    then
      echo -e "Failed to unzip $BOOTSTRAP_ZIP_NAME"
    else
      rm -rf $BOOTSTRAP_ZIP_NAME*
      rm -rf $CONFIGFOLDER/blocks
      rm -rf $CONFIGFOLDER/chainstate
      rm -rf $CONFIGFOLDER/peers.dat

      echo -e "Successfully installed bootstrap"
    fi
  fi
}

function addBootstrap() {
  checkBootstrap
  bootstrapCheck=$?
  if [[ $bootstrapCheck != 0 ]]
  then
    echo -e "Installing bootstrap"
    installBootstrap
  fi
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

function commandList() {

  if [[ -z "$(ps axo cmd:100 | egrep $COIN_DAEMON | grep ^[^grep])" ]]; then
    echo -e "XSN Daemon is not running"
  else
     shouldloop=true;
     while $shouldloop; do

       echo -e "1: Wallet-Information"
       echo -e "2: Blockchain-Information"
       echo -e "3: Network-Information"
       echo -e "4: Synchronisation-Information"
       echo -e "5: Back to Menu"

       echo -e "════════════════════════════"
       read -rp "Please select your choice: " opt
       echo -e "════════════════════════════"

       case $opt in
         "1") $CONFIGFOLDER/$COIN_CLIENT $WALLETINFO
         ;;
         "2") $CONFIGFOLDER/$COIN_CLIENT $BLOCKCHAININFO
         ;;
         "3") $CONFIGFOLDER/$COIN_CLIENT $NETWORKINFO
         ;;
         "4") $CONFIGFOLDER/$COIN_CLIENT $ISSYNCED
         ;;
         "5") shouldloop=false;
         menu
         break;
         ;;

         *) echo "invalid option";;
        esac
      done
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
  #clear
  showName
  checks

  echo -e "Masternode script $SCRIPTVER"
  echo -e "════════════════════════════"
  echo -e "══════════ Menu ════════════"
  echo -e "════════════════════════════"

  echo -e "════════════════════════════"
  echo -e "1: Install full Masternode"
  echo -e "2: Update Masternode"
  echo -e "3: List Commands"
  echo -e "4: Exit"
  echo -e "════════════════════════════"

  #PS3="Ihre Wahl : "
  read -rp "Please select your choice: " opt
  case $opt in
    "1") echo -e "Install full Masternode"
         doFullMasternode
    ;;
    "2") echo -e "Update Masternode"
         doUpdateMasternode
    ;;
    "3") commandList
    ;;

    "4") exit
    ;;

    *) echo "invalid option";;
   esac
}

menu

#coldlook=$(cat ~/.aegeus/debug.log |grep cold)
#last20=$(tail ~/.aegeus/debug.log -n20)
