#!/bin/bash

#Debug
#COIN_GIT='https://github.com/X9Developers/XSN/releases/download/v1.0.13/xsn-1.0.13-linux64.tar.gz'
#FILE_NAME_TAR='xsn-1.0.13-linux64.tar.gz'
#FILE_NAME='xsn-1.0.13'

#Update Wallet version
SCRIPTVER=1.0.1
SCRIPT_NAME='stakenet_mninstaller.sh'

COIN_NAME='XSN'
CONFIG_FILE='xsn.conf'
CONFIGFOLDER="$HOME/.xsncore"
COIN_BACKUP="$HOME/XSNBackup"
COIN_CLIENT='xsn-cli'
COIN_DAEMON='xsnd'
COIN_PORT=62583
#Updateable
COIN_GIT='https://github.com/X9Developers/XSN/releases/download/v1.0.15/xsn-1.0.15-linux64.tar.gz'
FILE_NAME_TAR='xsn-1.0.15-linux64.tar.gz'
FILE_NAME='xsn-1.0.15'
WALLET_VER='1001500'

BOOTSTRAP_LINK='https://github.com/X9Developers/XSN/releases/download/v1.0.13/bootstrap.dat.zip'
BOOTSTRAP_ZIP_NAME='bootstrap.dat.zip'
BOOTSTRAP_FILE_NAME='bootstrap.dat'

#Importand commands
ISSYNCED='mnsync status'
BLOCKCHAININFO='getblockchaininfo'
NETWORKINFO='getnetworkinfo'
WALLETINFO='getwalletinfo'
MNSTATUS='masternode status'

#Console commands
GREENTICK='\033[0;32m\xE2\x9C\x94\033[0m'
CURSOR_PREVIOUS_LINE='\033[1A'
RED='\E[31m'
GREEN='\E[32m'
BLINK='\E[5m'
OFF='\E[0m'

#Global variables
NODE_IP=""
WALLET_TIMEOUT_S=60   #Test showed that the wallet is up after 60 seconds

function doFullMasternode() {
  clear
  installDependencies
  deleteOldInstallationAndBackup
  memorycheck
  enable_firewall
  downloadInstallNode
  coreConfiguration
  addBootstrap
  startXsnDaemon
  printInformationDuringSync
  outro
}

function doUpdateMasternode {
  clear
  backupData

  if  [[ $? -ne 1 ]]; then
    checkWalletVersion
    stopAndDelOldDaemon
    downloadInstallNode
    recoverBackup
    addBootstrap
    startXsnDaemon
    printInformationDuringSync
    outro
  else
    menu
  fi
}

function backupData() {
  if [[ -f $( eval echo "$CONFIGFOLDER/wallet.dat" ) ]]; then
    echo -e "Found existing xsncore, making backup..."

    if [[ ! -d $( eval echo "$COIN_BACKUP" ) ]]; then
      mkdir $( eval echo $COIN_BACKUP )
    fi

    cp $( eval echo $CONFIGFOLDER/xsn.conf $COIN_BACKUP ) 2> /dev/null
    cp $( eval echo $CONFIGFOLDER/wallet.dat $COIN_BACKUP ) 2> /dev/null

    echo -e "$GREENTICK Backup done!"
  else
    echo -e "${RED}ERROR:${OFF} No $COIN_NAME install found"
    echo -e ""
    echo -e "Do you want a full Masternode install?"
    echo -e "1: Yes"
    echo -e "2: No"

    read -rp "" opt
    case $opt in
      "1") return 1
      ;;
      "2") exit
      ;;
      *) echo -e "${RED}ERROR:${OFF} Invalid option"
          exit
      ;;
     esac
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
    echo -e "Shutting daemon down again.."
    2>/dev/null 1>/dev/null $CONFIGFOLDER/$COIN_CLIENT stop
  fi

  if [[ ${walletVersion::-1} -ge $WALLET_VER ]]; then
    echo -e "$GREENTICK You are already running the latest XSN-Core!"
    exit
  fi

  echo -e "Starting Update.."
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
    echo -ne "Installing dependencies${BLINK}..${OFF}"
    echo "y" | apt update > /dev/null 2>&1
    #echo "y" | apt upgrade > /dev/null 2>&1
    echo "y" | apt install -y ufw python virtualenv git unzip pv > /dev/null 2>&1
    echo -e \\r"Installing dependencies.."
    echo -e "$GREENTICK Dependency install done!"
}

function deleteOldInstallationAndBackup() {
  if [[ -f $( eval echo "$CONFIGFOLDER/wallet.dat" ) ]]; then
    echo -e "Found existing xsncore, making backup.."

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
    2>/dev/null 1>/dev/null $CONFIGFOLDER/$COIN_CLIENT stop

    while [[ -z "$(ps axo cmd:100 | egrep $COIN_DAEMON | grep ^[^grep])" ]]
    do
      sleep 1
    done
  fi
}

function memorycheck() {

  echo -e "Checking Memory.."
  FREEMEM=$( free -m |sed -n '2,2p' |awk '{ print $4 }' )
  SWAPS=$( free -m |tail -n1 |awk '{ print $2 }' )

  if [[ $FREEMEM -lt 2048 ]]; then
    if [[ $SWAPS -eq 0 ]]; then
      echo -e "Adding swap.."
      fallocate -l 4G /swapfile
  		chmod 600 /swapfile
  		mkswap /swapfile
  		swapon /swapfile
  		cp /etc/fstab /etc/fstab.bak
  		echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

      echo -e "$GREENTICK Added 4G Swapfile!"
    else
      echo -e "$GREENTICK Swapsize: $SWAPS, thats enough!"
    fi
  else
    echo -e "$GREENTICK Freemem: $FREEMEN, thats enough free RAM!"
  fi

}

function enable_firewall() {
  echo -e "Setting up firewall to allow traffic on port $COIN_PORT.."
  ufw allow ssh/tcp >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw allow $COIN_PORT/tcp >/dev/null 2>&1
  ufw logging on >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
  echo -e "$GREENTICK Firewall setup done!"
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
  echo -e "Downloading and installing VPS XSN daemon.."
  rm -rf $FILE_NAME_TAR*

  if [[ ! -d $( eval echo "$CONFIGFOLDER" ) ]]; then
    mkdir $( eval echo $CONFIGFOLDER )
  fi

  wget --progress=bar:force $COIN_GIT 2>&1 | progressfilt
  if [ $? -ne 0 ]
  then
    echo -e "${RED}ERROR:${OFF} Failed to download $COIN_GIT!"
    exit
  fi

  tar xfvz $FILE_NAME_TAR*  > /dev/null 2>&1
  if [ $? -ne 0 ]
  then
    echo -e "${RED}ERROR:${OFF} Failed to unzip $FILE_NAME_TAR!"
    exit
  fi

  cp $FILE_NAME/bin/xsnd $CONFIGFOLDER > /dev/null 2>&1
  cp $FILE_NAME/bin/xsn-cli $CONFIGFOLDER > /dev/null 2>&1
  chmod 777 $CONFIGFOLDER/xsn*

  #Clean up
  rm -rf $FILE_NAME*

  echo -e "$GREENTICK VPS XSN daemon installation done!"
}

function coreConfiguration() {
  echo -e "Generating $COIN_NAME config.."

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
  echo -e "Using IP Address $NODE_IP.."

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

  echo -e "$GREENTICK Finished $CONFIG_FILE configuration!"
}

function startXsnDaemon() {
  echo -e "Starting $COIN_NAME daemon (takes up to $WALLET_TIMEOUT_S seconds).."
  2>/dev/null 1>/dev/null $CONFIGFOLDER/$COIN_DAEMON

  #WaitOnServerStart
  waitWallet="-1"
  retryCounter=0
  echo -ne "Waiting on wallet${BLINK}..${OFF}"
  while [[ $waitWallet -ne "0" && $retryCounter -lt $WALLET_TIMEOUT_S ]]
  do
    sleep 1
    2>/dev/null 1>/dev/null $CONFIGFOLDER/$COIN_CLIENT $BLOCKCHAININFO
    waitWallet="$?"
    retryCounter=$[retryCounter+1]
  done

  echo -e \\r"Waiting on wallet.."
  if [[ $retryCounter -ge $WALLET_TIMEOUT_S ]]; then
    echo -e "${RED}ERROR:${OFF}"
    printErrorLog
    exit
  else
    echo -e "$GREENTICK Wallet startup successful!"
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
  echo -e "$GREENTICK Synchronisation finished!"
}

function printErrorLog() {
  error=$( (cat $CONFIGFOLDER/debug.log |grep Error) )
  echo -e "$error"
}


function getIP() {
  foundAddr=$( eval ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')

  if [[ "$foundAddr" = *$'\n'* ]]; then
    echo -e "More than one IP address found.."
    echo -e "Select the one you want to use"

    select option in $foundAddr
    do
       case "$option" in
          End)  echo "End"; break ;;
            "")  echo -e "${RED}ERROR:${OFF} Invalid selection" ;;
             *)  NODE_IP="$option"
                 break
       esac
    done
  else
      echo -e "Found IP Address $foundAddr.."
      NODE_IP="$foundAddr"
  fi
}

function checkBootstrap() {
  if [ -f $CONFIGFOLDER/$BOOTSTRAP_FILE_NAME* ]
  then
    echo -e "Bootstrap already installed.."
    return 0
  else
    echo -e "Bootstrap not found.."
    return 1
  fi
}

function installBootstrap() {
  rm -rf $BOOTSTRAP_ZIP_NAME*
  wget --progress=bar:force $BOOTSTRAP_LINK 2>&1 | progressfilt
  if [ $? -ne 0 ]
  then
    echo -e "${RED}ERROR:${OFF} Failed to download $BOOTSTRAP_FILE_NAME"
  else
    unzip -j $BOOTSTRAP_ZIP_NAME* $BOOTSTRAP_FILE_NAME -d $CONFIGFOLDER
    if [ $? -ne 0 ]
    then
      echo -e "${RED}ERROR:${OFF} Failed to unzip $BOOTSTRAP_ZIP_NAME"
    else
      rm -rf $BOOTSTRAP_ZIP_NAME*
      rm -rf $CONFIGFOLDER/blocks
      rm -rf $CONFIGFOLDER/chainstate
      rm -rf $CONFIGFOLDER/peers.dat

      echo -e "$GREENTICK Successfully installed bootstrap!"
    fi
  fi
}

function addBootstrap() {
  checkBootstrap
  bootstrapCheck=$?
  if [[ $bootstrapCheck != 0 ]]
  then
    echo -e "Installing bootstrap.."
    installBootstrap
  fi
}

function checks() {
  if [[ $( lsb_release -d ) != *16.04* ]] && [[ $( lsb_release -d ) != *18.04* ]]; then
    echo -e "${RED}ERROR:${OFF} You are not running Ubuntu 16.04 or 18.04. Installation is cancelled."
    exit 1
  fi

  if [[ $EUID -ne 0 ]]; then
     echo -e "${RED}ERROR:${OFF} Must be run as root (try \"sudo $SCRIPT_NAME\" )"
     exit 1
  fi
}

function commandList() {

  if [[ -z "$(ps axo cmd:100 | egrep $COIN_DAEMON | grep ^[^grep])" ]]; then
    echo -e "${RED}ERROR:${OFF} XSN Daemon is not running"
  else
     shouldloop=true;
     while $shouldloop; do

       echo -e "1: Wallet-Information"
       echo -e "2: Blockchain-Information"
       echo -e "3: Network-Information"
       echo -e "4: Synchronisation-Information"
       echo -e "5: Masternode-Status"
       echo -e "6: Back to Menu"

       echo -e "════════════════════════════"
       read -rp "Please select your choice: " opt
       echo -e "════════════════════════════"

       case $opt in
         "1") echo -e "${GREEN}$($CONFIGFOLDER/$COIN_CLIENT $WALLETINFO)${OFF}"
         ;;
         "2") echo -e "${GREEN}$($CONFIGFOLDER/$COIN_CLIENT $BLOCKCHAININFO)${OFF}"
         ;;
         "3") echo -e "${GREEN}$($CONFIGFOLDER/$COIN_CLIENT $NETWORKINFO)${OFF}"
         ;;
         "4") echo -e "${GREEN}$($CONFIGFOLDER/$COIN_CLIENT $ISSYNCED)${OFF}"
         ;;
         "5") echo -e "${GREEN}$($CONFIGFOLDER/$COIN_CLIENT $MNSTATUS)${OFF}"
         ;;
         "6") shouldloop=false;
         menu
         break;
         ;;

         *) echo -e "${RED}ERROR:${OFF} Invalid option";;
        esac
      done
  fi
}

function outro() {
  clear
  showName
  echo -e "${GREENTICK} Setup finished. Now you can start your masternode from your local wallet!"
  echo -e ""
  echo -e ""
  creatorName
  echo -e "Donations always accepted gracefully to:"
  echo -e "XSN: XjS84bRgYd83hikHjhnQWQJJGDueFQEM1m"
  echo -e "BTC: 16azsAD43MWoBDkfRvdKt6GprdjYSrw2bL"
}

function creatorName() {
  echo -e "      ·▄▄▄▄  ▄▄▄ . ▐ ▄        ▐ ▄ "
  echo -e "      ██▪ ██ ▀▄.▀·•█▌▐█▪     •█▌▐█"
  echo -e "      ▐█· ▐█▌▐▀▀▪▄▐█▐▐▌ ▄█▀▄ ▐█▐▐▌"
  echo -e "      ██. ██ ▐█▄▄▌██▐█▌▐█▌.▐▌██▐█▌"
  echo -e "      ▀▀▀▀▀•  ▀▀▀ ▀▀ █▪ ▀█▄▀▪▀▀ █▪"
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

  echo -e "Masternode script $SCRIPTVER (from Denon)"
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
    "1") echo -e "Install full Masternode.."
         doFullMasternode
    ;;
    "2") echo -e "Update Masternode.."
         doUpdateMasternode
    ;;
    "3") commandList
    ;;

    "4") exit
    ;;

    *) echo -e "${RED}ERROR:${OFF} Invalid option";;
   esac
}

menu
