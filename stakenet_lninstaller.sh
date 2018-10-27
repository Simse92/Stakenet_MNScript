#!/bin/bash
SCRIPTVER=1.0.1

WALLET_TIMEOUT_S=60
NETWORK=''
EXCHANGE=''

#logging
DATE_STAMP="$(date +%y-%m-%d-%s)"
SCRIPT_LOGFOLDER="/tmp/ln_install_${DATE_STAMP}_log/"
SCRIPT_INTERNAL_LOGFILE="${SCRIPT_LOGFOLDER}/script.log"
SCRIPT_XA_LTC_LOGFILE="${SCRIPT_LOGFOLDER}/xa_ltc.log"
SCRIPT_XA_XSN_LOGFILE="${SCRIPT_LOGFOLDER}/xa_xsn.log"
SCRIPT_XA_RESOLVER_LOGFILE="${SCRIPT_LOGFOLDER}/xa_resolver.log"
SCRIPT_XB_LTC_LOGFILE="${SCRIPT_LOGFOLDER}/xb_ltc.log"
SCRIPT_XB_XSN_LOGFILE="${SCRIPT_LOGFOLDER}/xb_xsn.log"
SCRIPT_XB_RESOLVER_LOGFILE="${SCRIPT_LOGFOLDER}/xb_resolver.log"

#litecoin
LTC_CODE_NAME='LTC'
LTC_DAEMON='litecoind'
LTC_CLIENT='litecoin-cli'
LTC_COIN_GIT='https://download.litecoin.org/litecoin-0.16.3/linux/litecoin-0.16.3-x86_64-linux-gnu.tar.gz'
LTC_FILE_NAME_TAR='litecoin-0.16.3-x86_64-linux-gnu.tar.gz'
LTC_FILE_NAME='litecoin-0.16.3'
LTC_CONFIGFOLDER="$HOME/.litecoin"
LTC_CONFIG_FILE='litecoin.conf'
LTC_RPC_USER=''
LTC_RPC_PASS=''
LTC_ZMQ_BLOCK_PORT='28332'
LTC_ZMQ_TX_PORT='28333'


#stakenet
XSN_CODE_NAME='XSN'
XSN_DAEMON='xsnd'
XSN_CLIENT='xsn-cli'
XSN_COIN_GIT=''
#testnet
XSN_COIN_GIT_TESTNET='https://github.com/X9Developers/lnd/raw/master/wallets/xsn-1.0.16-x86_64-linux-gnu.tar.gz'
#mainnet
XSN_COIN_GIT_MAINNET='https://github.com/X9Developers/XSN/releases/download/v1.0.16/xsn-1.0.16-x86_64-linux-gnu.tar.gz'
XSN_FILE_NAME_TAR='xsn-1.0.16-x86_64-linux-gnu.tar.gz'
XSN_FILE_NAME='xsn-1.0.16'
XSN_CONFIGFOLDER="$HOME/.xsncore"
XSN_CONFIG_FILE='xsn.conf'
XSN_RPC_USER=''
XSN_RPC_PASS=''
XSN_ZMQ_BLOCK_PORT='28444'
XSN_ZMQ_TX_PORT='28445'


LNDGIT='https://github.com/X9Developers/swap-resolver/releases/download/v1.0.0'
LNDPATH="$HOME/lnd"
GOPATH="$HOME/go"
RESOLVERPATH="$GOPATH/src/github.com/ExchangeUnion/swap-resolver"

RETURN_VAR=""

#commands
BLOCKCHAININFO='getblockchaininfo'
NETWORKINFO='getnetworkinfo'
SYNCINFO='getinfo'

#Console commands
GREENTICK='\033[0;32m\xE2\x9C\x94\033[0m'
CURSOR_PREVIOUS_LINE='\033[1A'
RED='\E[31m'
GREEN='\E[32m'
BLINK='\E[5m'
OFF='\E[0m'

function doFullSetup() {
  clear
  deleteOldInstallation
  networkRequest
  installDependencies
  enable_firewall
  configureGOPath
  memorycheck

  installGenWallet $LTC_CODE_NAME $LTC_FILE_NAME_TAR $LTC_FILE_NAME $LTC_CONFIGFOLDER $LTC_COIN_GIT $LTC_DAEMON $LTC_CLIENT
  createGenConfig $LTC_CODE_NAME $LTC_CONFIGFOLDER $LTC_CONFIG_FILE $LTC_ZMQ_BLOCK_PORT $LTC_ZMQ_TX_PORT

  IFS=';' read -ra ret_ltc <<< "$RETURN_VAR"
  LTC_RPC_USER=${ret_ltc[0]}
  LTC_RPC_PASS=${ret_ltc[1]}

  startGenWallet $LTC_CODE_NAME $LTC_CONFIGFOLDER $LTC_DAEMON $LTC_CLIENT

  installGenWallet $XSN_CODE_NAME $XSN_FILE_NAME_TAR $XSN_FILE_NAME $XSN_CONFIGFOLDER $XSN_COIN_GIT $XSN_DAEMON $XSN_CLIENT
  createGenConfig $XSN_CODE_NAME $XSN_CONFIGFOLDER $XSN_CONFIG_FILE $XSN_ZMQ_BLOCK_PORT $XSN_ZMQ_TX_PORT

  IFS=';' read -ra ret_xsn <<< "$RETURN_VAR"
  XSN_RPC_USER=${ret_xsn[0]}
  XSN_RPC_PASS=${ret_xsn[1]}

  startGenWallet $XSN_CODE_NAME $XSN_CONFIGFOLDER $XSN_DAEMON $XSN_CLIENT

  if  [[ "$NETWORK" == "testnet" ]]; then
  $XSN_CONFIGFOLDER/$XSN_CLIENT addnode 107.21.133.151 onetry
  $XSN_CONFIGFOLDER/$XSN_CLIENT addnode ec2-34-228-111-185.compute-1.amazonaws.com onetry
  $XSN_CONFIGFOLDER/$XSN_CLIENT addnode 34.228.111.185 onetry
  fi

  installANDconfigureLNDDeamons
  installANDconfigureSwapResolver

  #####
  echo -e "${GREENTICK} Full setup finished. Now you can start the lighting daemons!"
  echo -e ""
  echo -e ""
  menu
  #####

}

function deleteOldInstallation() {

  ps aux | grep -ie lnd | awk '{print $2}' | xargs kill -9 &>> ${SCRIPT_INTERNAL_LOGFILE}
  stopDaemon $XSN_DAEMON $XSN_CONFIGFOLDER $XSN_CLIENT &>> ${SCRIPT_INTERNAL_LOGFILE}
  stopDaemon $LTC_DAEMON $LTC_CONFIGFOLDER $LTC_CLIENT &>> ${SCRIPT_INTERNAL_LOGFILE}

  rm -r $XSN_CONFIGFOLDER &>> ${SCRIPT_INTERNAL_LOGFILE}
  rm -r $LTC_CONFIGFOLDER &>> ${SCRIPT_INTERNAL_LOGFILE}
  rm -r $LNDPATH &>> ${SCRIPT_INTERNAL_LOGFILE}
  rm -r $GOPATH/src/github.com/ExchangeUnion &>> ${SCRIPT_INTERNAL_LOGFILE}

  sed -i '/GOPATH/d' ~/.bashrc &>> ${SCRIPT_INTERNAL_LOGFILE}
  sed -i '/go/d' ~/.bashrc &>> ${SCRIPT_INTERNAL_LOGFILE}

  rm /usr/local/bin/xa-lnd-xsn &>> ${SCRIPT_INTERNAL_LOGFILE}
  rm /usr/local/bin/xb-lnd-xsn &>> ${SCRIPT_INTERNAL_LOGFILE}
  rm /usr/local/bin/xa-lnd-ltc &>> ${SCRIPT_INTERNAL_LOGFILE}
  rm /usr/local/bin/xb-lnd-ltc &>> ${SCRIPT_INTERNAL_LOGFILE}
}

function memorycheck() {

  echo -e "Checking Memory.."
  TOTAL_MEM=$( free -m |sed -n '2,2p' |awk '{ print $2 }' )
  SWAP=$( free -m |tail -n1 |awk '{ print $2 }' )
  DESIRED_SWAP=4000

  echo -e "Total Memory: $TOTAL_MEM, Current Swap: $SWAP, Desired Swap: $DESIRED_SWAP"

  if [[ $SWAP -lt $DESIRED_SWAP ]]; then
    echo -e "Adding $DESIRED_SWAP swap.."
    fallocate -l $DESIRED_SWAP /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    cp /etc/fstab /etc/fstab.bak
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

    echo -e "$GREENTICK Added $DESIRED_SWAP Swapfile!"
  else
    echo -e "$GREENTICK Swapsize: $SWAP, thats enough!"
  fi

}


function stopDaemon() {
  #PARAMS
  #1:COIN_DAEMON, 2: COIN_CONFIGFOLDER, 3:COIN_CLIENT
  if [[ ! -z "$(ps axo cmd:100 | egrep $1 | grep ^[^grep])" ]]; then
    $2/$3 stop &>> ${SCRIPT_INTERNAL_LOGFILE}

  while [[ -z "$(ps axo cmd:100 | egrep $1 | grep ^[^grep])" ]]
  do
    sleep 1
  done
  fi
}

function startGenWallet() {
  #PARAMS
  #1:COIN_CODE_NAME, 2:COIN_CONFIGFOLDER, 3:COIN_DAEMON, 4:COIN_CLIENT,
  echo -e "Starting $1 daemon (takes up to $WALLET_TIMEOUT_S seconds).."
  $2/$3 &>> ${SCRIPT_INTERNAL_LOGFILE}

  # WaitOnServerStart
  waitWallet="-1"
  retryCounter=0
  echo -e "Waiting on $1 wallet${BLINK}..${OFF}"
  while [[ $waitWallet -ne "0" && $retryCounter -lt $WALLET_TIMEOUT_S ]]
  do
    sleep 1
    $2/$4 $BLOCKCHAININFO &>> ${SCRIPT_INTERNAL_LOGFILE}
    waitWallet="$?"
    retryCounter=$[retryCounter+1]
  done

  if [[ $retryCounter -ge $WALLET_TIMEOUT_S ]]; then
    echo -e "${RED}ERROR:${OFF}"
    printErrorLog
    exit
  else
    echo -e "$GREENTICK $1 wallet startup successful!"
  fi
}

function createGenConfig() {
  #PARAMS
  #1:COIN_CODE_NAME, 2:COIN_CONFIGFOLDER, 3:COIN_CONFIG_FILE 4:COIN_ZMQ_BLOCK_PORT, 5:COIN_ZMQ_TX_PORT
  echo -e "Generating $1 config.."

  USER=$(openssl rand -hex 11)
  PASSWORD=$(openssl rand -hex 20)

cat << EOF > $(eval echo $2/$3)
  #=========
  rpcallowip=127.0.0.1
  rpcuser=$USER
  rpcpassword=$PASSWORD
  #=========
  zmqpubrawblock=tcp://127.0.0.1:$4
  zmqpubrawtx=tcp://127.0.0.1:$5
  #=========
  listen=1
  server=1
  daemon=1
  $NETWORK=1
  #=========

EOF
  echo -e "$GREENTICK Finished $1 config configuration!"

  RETURN_VAR="$USER;$PASSWORD"
}

function installGenWallet() {
  #PARAMS
  # 1:COIN_CODE_NAME, 2:COIN_FILE_NAME_TAR, 3:COIN_FILE_NAME, 4:COIN_CONFIGFOLDER, 5:COIN_GIT, 6:COIN_DAEMON, 7:COIN_CLIENT
  echo -e "Downloading and installing $1 daemon.."
  rm -rf $2* &>> ${SCRIPT_INTERNAL_LOGFILE}

  if [[ ! -d $( eval echo "$4" ) ]]; then
    mkdir $( eval echo $4 ) &>> ${SCRIPT_INTERNAL_LOGFILE}
  fi

  wget --progress=bar:force $5 2>&1 | progressfilt
  if [ $? -ne 0 ]
  then
    echo -e "${RED}ERROR:${OFF} Failed to download $5!"
    exit
  fi

  tar xfvz $2* &>> ${SCRIPT_INTERNAL_LOGFILE}
  if [ $? -ne 0 ]
  then
    echo -e "${RED}ERROR:${OFF} Failed to unzip $2!"
    exit
  fi

  cp $3/bin/$6 $4 &>> ${SCRIPT_INTERNAL_LOGFILE}
  cp $3/bin/$7 $4 &>> ${SCRIPT_INTERNAL_LOGFILE}
  chmod 777 $4/$6 &>> ${SCRIPT_INTERNAL_LOGFILE}
  chmod 777 $4/$7 &>> ${SCRIPT_INTERNAL_LOGFILE}

  #Clean up
  rm -rf $3* &>> ${SCRIPT_INTERNAL_LOGFILE}

  echo -e "$GREENTICK $1 daemon installation done!"
}

function installANDconfigureLNDDeamons() {
  echo -e "Downloading and installing Lightning daemons${BLINK}..${OFF}"
  mkdir $LNDPATH &>> ${SCRIPT_INTERNAL_LOGFILE}
  wget $LNDGIT/lncli -P $LNDPATH &>> ${SCRIPT_INTERNAL_LOGFILE}
  wget $LNDGIT/lnd_ltc -P $LNDPATH &>> ${SCRIPT_INTERNAL_LOGFILE}
  wget $LNDGIT/lnd_xsn -P $LNDPATH &>> ${SCRIPT_INTERNAL_LOGFILE}

  chmod 777 $LNDPATH/ln* &>> ${SCRIPT_INTERNAL_LOGFILE}

  # Adding lncli commands
  echo -e "$LNDPATH/lncli --network $NETWORK --rpcserver=localhost:10003 --no-macaroons \"\$@\" " >> /usr/local/bin/xa-lnd-xsn
  echo -e "$LNDPATH/lncli --network $NETWORK --rpcserver=localhost:10001 --no-macaroons \"\$@\" " >> /usr/local/bin/xa-lnd-ltc
  echo -e "$LNDPATH/lncli --network $NETWORK --rpcserver=localhost:20003 --no-macaroons \"\$@\" " >> /usr/local/bin/xb-lnd-xsn
  echo -e "$LNDPATH/lncli --network $NETWORK --rpcserver=localhost:20001 --no-macaroons \"\$@\" " >> /usr/local/bin/xb-lnd-ltc


  chmod 777 /usr/local/bin/x* &>> ${SCRIPT_INTERNAL_LOGFILE}

  echo -e "$GREENTICK Lightning daemon installation done!"
}

function installANDconfigureSwapResolver() {
  echo -e "Installing Swap-Resolver${BLINK}..${OFF}"
  git clone https://github.com/X9Developers/swap-resolver.git $GOPATH/src/github.com/ExchangeUnion/swap-resolver &>> ${SCRIPT_INTERNAL_LOGFILE}

  # Set rpcUserPass LTC
  sed -i "s|user=xu|user=$LTC_RPC_USER|g" $RESOLVERPATH/exchange-a/lnd/ltc/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}
  sed -i "s|pass=xu|pass=$LTC_RPC_PASS|g" $RESOLVERPATH/exchange-a/lnd/ltc/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}

  sed -i "s|user=xu|user=$LTC_RPC_USER|g" $RESOLVERPATH/exchange-b/lnd/ltc/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}
  sed -i "s|pass=xu|pass=$LTC_RPC_PASS|g" $RESOLVERPATH/exchange-b/lnd/ltc/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}

  ## Set network LTC
  sed -i "s|testnet|$NETWORK|g" $RESOLVERPATH/exchange-a/lnd/ltc/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}
  sed -i "s|testnet|$NETWORK|g" $RESOLVERPATH/exchange-b/lnd/ltc/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}

  ### Set daemon LTC
  sed -i "s|localhost:10011|0.0.0.0:10011|g" $RESOLVERPATH/exchange-a/lnd/ltc/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}
  sed -i "s|localhost:20011|0.0.0.0:20011|g" $RESOLVERPATH/exchange-b/lnd/ltc/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}

  ### Set liste to all interfaces
  sed -i "s|lnd|$LNDPATH/lnd_ltc|g" $RESOLVERPATH/exchange-a/lnd/ltc/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}
  sed -i "s|lnd|$LNDPATH/lnd_ltc|g" $RESOLVERPATH/exchange-b/lnd/ltc/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}

  # Set rpcUserPass XSN
  sed -i "s|user=xu|user=$XSN_RPC_USER|g" $RESOLVERPATH/exchange-a/lnd/xsn/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}
  sed -i "s|pass=xu|pass=$XSN_RPC_PASS|g" $RESOLVERPATH/exchange-a/lnd/xsn/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}

  sed -i "s|user=xu|user=$XSN_RPC_USER|g" $RESOLVERPATH/exchange-b/lnd/xsn/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}
  sed -i "s|pass=xu|pass=$XSN_RPC_PASS|g" $RESOLVERPATH/exchange-b/lnd/xsn/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}

  ## Set network XSN
  sed -i "s|testnet|$NETWORK|g" $RESOLVERPATH/exchange-a/lnd/xsn/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}
  sed -i "s|testnet|$NETWORK|g" $RESOLVERPATH/exchange-b/lnd/xsn/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}

  ### Set daemon XSN
  sed -i "s|lnd|$LNDPATH/lnd_xsn|g" $RESOLVERPATH/exchange-a/lnd/xsn/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}
  sed -i "s|lnd|$LNDPATH/lnd_xsn|g" $RESOLVERPATH/exchange-b/lnd/xsn/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}

  ### Set daemon LTC
  sed -i "s|localhost:10013|0.0.0.0:10013|g" $RESOLVERPATH/exchange-a/lnd/xsn/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}
  sed -i "s|localhost:20013|0.0.0.0:20013|g" $RESOLVERPATH/exchange-b/lnd/xsn/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}

  #### Set Resolver
  sed -i "s|localhost:7001|0.0.0.0:7001|g" $RESOLVERPATH/exchange-a/resolver/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}
  sed -i "s|localhost:7002|0.0.0.0:7002|g" $RESOLVERPATH/exchange-b/resolver/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}

  echo -e "$GREENTICK Swap-Resolver installation done!"
}

function configureGOPath() {
  echo -e "export GOPATH=$HOME/go" >> ~/.bashrc
  echo -e "export PATH=/usr/bin/go/bin:$GOPATH/bin:$PATH" >> ~/.bashrc
  source ~/.bashrc
}

function installDependencies() {
  echo -ne "Installing dependencies${BLINK}..${OFF}"
  echo "y" | apt update &>> ${SCRIPT_INTERNAL_LOGFILE}
  #echo "y" | apt upgrade &>> ${SCRIPT_INTERNAL_LOGFILE}
  echo "y" | apt install -y ufw python virtualenv git unzip pv golang-go &>> ${SCRIPT_INTERNAL_LOGFILE}
  echo -e \\r"Installing dependencies.."
  echo -e "$GREENTICK Dependency install done!"
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

function networkRequest() {
  echo -e "Which network should be used?"
  echo -e "1: Mainnet"
  echo -e "2: Testnet"

  read -rp "" opt
  case $opt in
  "1") echo -e "Mainnet Let's do it"
     NETWORK='mainnet'
     XSN_COIN_GIT=$XSN_COIN_GIT_MAINNET
  ;;
  "2") echo -e "Testnet Let's do it"
     NETWORK='testnet'
     XSN_COIN_GIT=$XSN_COIN_GIT_TESTNET
  ;;
  *) echo -e "${RED}ERROR:${OFF} Invalid option"
    exit
  ;;
   esac
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

function checks() {
  if [[ $( lsb_release -d ) != *16.04* ]] && [[ $( lsb_release -d ) != *18.04* ]]; then
    echo -e "${RED}ERROR:${OFF} You are not running Ubuntu 16.04 or Ubuntu 18.04. Installation is cancelled."
    exit 1
  fi

  if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}ERROR:${OFF} Must be run as root (try \"sudo $SCRIPT_NAME\" )"
   exit 1
  fi
}
################################################################################
###############################Lightning########################################
################################################################################
function doLightningNetwork() {
  checkIfCoreWalletIsUp $XSN_DAEMON $XSN_CODE_NAME
  checkIfCoreWalletIsUp $LTC_DAEMON $LTC_CODE_NAME
  checkSyncStatus
  startLightningDaemons
  #establishConnection
  outro
}

function doLightningNetworkWithPartner {
  whichExchange
  configureExchange
  checkIfCoreWalletIsUp $XSN_DAEMON $XSN_CODE_NAME
  checkIfCoreWalletIsUp $LTC_DAEMON $LTC_CODE_NAME
  checkSyncStatus

  startOwnExchange

}

function startOwnExchange() {
  echo -e "Starting Lightning Daemons - This can take up to a minute.."

  if [ "$EXCHANGE" == "A" ]; then
    cd $RESOLVERPATH/exchange-a/lnd/xsn/
    nohup ./start.bash &>> ${SCRIPT_XA_XSN_LOGFILE} &
    echo -e "XSN-Exchange A started.."
    sleep 5
    cd $RESOLVERPATH/exchange-a/lnd/ltc/
    nohup ./start.bash &>> ${SCRIPT_XA_LTC_LOGFILE} &
    echo -e "LTC-Exchange A started.."
    sleep 5
    cd $RESOLVERPATH/exchange-a/resolver/
    nohup ./start.bash ltc_xsn &>> ${SCRIPT_XA_RESOLVER_LOGFILE} &
    echo -e "Resolver-Exchange A started.."
  fi

  if [ "$EXCHANGE" == "B" ]; then
    cd $RESOLVERPATH/exchange-b/lnd/xsn/
    nohup ./start.bash &>> ${SCRIPT_XB_XSN_LOGFILE} &
    echo -e "XSN-Exchange B started.."
    sleep 5
    cd $RESOLVERPATH/exchange-b/lnd/ltc/
    nohup ./start.bash &>> ${SCRIPT_XB_LTC_LOGFILE} &
    echo -e "LTC-Exchange B started.."
    sleep 5
    cd $RESOLVERPATH/exchange-b/resolver/
    nohup ./start.bash ltc_xsn &>> ${SCRIPT_XB_RESOLVER_LOGFILE} &
    echo -e "Resolver-Exchange B started.."
  fi

  echo -e "Wait 60 seconds..Until all daemons are started."
  sleep 60
}

function configureExchange() {
  echo -e "We need the IPv4 address from your Partner."
  read -rp "Use the following scheme XXX.XXX.XXX.XXX: " VPSIP

  if [ "$EXCHANGE" == "A" ]; then
    sed -i "s|localhost:7002|$VPSIP:7002|g" $RESOLVERPATH/exchange-a/resolver/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}
    ufw allow 10011/tcp &>> ${SCRIPT_XB_XSN_LOGFILE}
    ufw allow 7001/tcp &>> ${SCRIPT_XB_XSN_LOGFILE}
    ufw allow 10013/tcp &>> ${SCRIPT_XB_XSN_LOGFILE}
  fi

  if [ "$EXCHANGE" == "B" ]; then
    sed -i "s|localhost:7001|$VPSIP:7001|g" $RESOLVERPATH/exchange-b/resolver/start.bash &>> ${SCRIPT_INTERNAL_LOGFILE}
    ufw allow 20011/tcp &>> ${SCRIPT_XB_XSN_LOGFILE}
    ufw allow 7002/tcp &>> ${SCRIPT_XB_XSN_LOGFILE}
    ufw allow 20013/tcp &>> ${SCRIPT_XB_XSN_LOGFILE}
  fi
}

function whichExchange() {
  echo -e "Which Exchange should be started?"
  echo -e "1: Exchange A"
  echo -e "2: Exchange B"

  read -rp "" opt
  case $opt in
  "1") echo -e "Exchange A"
     EXCHANGE='A'
  ;;
  "2") echo -e "Exchange B"
     EXCHANGE='B'
  ;;
  *) echo -e "${RED}ERROR:${OFF} Invalid option"
    exit
  ;;
   esac
}

function establishConnection() {
  echo -e "Establishing connection between exchanges.."
  sleep 1

  XB_XSN_PUBKEY=`xb-lnd-xsn getinfo|grep identity_pubkey|cut -d '"' -f 4`
  XB_LTC_PUBKEY=`xb-lnd-ltc getinfo|grep identity_pubkey|cut -d '"' -f 4`

  xa-lnd-xsn connect $XB_XSN_PUBKEY@127.0.0.1:20013 &>> ${SCRIPT_INTERNAL_LOGFILE}
  xa-lnd-ltc connect $XB_LTC_PUBKEY@127.0.0.1:20011 &>> ${SCRIPT_INTERNAL_LOGFILE}

  echo -e "$GREENTICK Connection establishment successful!"
}


function checkIfCoreWalletIsUp() {
  #PARAMS
  # 1:COIN_DAEMON, 2:COIN_NAME
  if [[ -z "$(ps axo cmd:100 | egrep $1 | grep ^[^grep])" ]]; then
    echo -e "${RED}ERROR:${OFF} $2 wallet not runnning."
    exit
  fi
}

function checkSyncStatusLNWallets()  {
  echo -e "Waiting for all Lightning daemons until they are synced with the wallets.."

  xa_xsn=$( (xa-lnd-xsn $SYNCINFO |grep 'synced_to_chain'|awk '{ print $2 }') )
  xa_xsn_actBlock=$( (xa-lnd-xsn $SYNCINFO |grep 'block_height'|awk '{ print $2 }') )

  xb_xsn=$( (xb-lnd-xsn $SYNCINFO |grep 'synced_to_chain'|awk '{ print $2 }') )
  xb_xsn_actBlock=$( (xb-lnd-xsn $SYNCINFO |grep 'block_height'|awk '{ print $2 }') )

  xa_ltc=$( (xa-lnd-ltc $SYNCINFO |grep 'synced_to_chain'|awk '{ print $2 }') )
  xa_ltc_actBlock=$( (xa-lnd-ltc $SYNCINFO |grep 'block_height'|awk '{ print $2 }') )

  xb_ltc=$( (xb-lnd-ltc $SYNCINFO |grep 'synced_to_chain'|awk '{ print $2 }') )
  xb_ltc_actBlock=$( (xb-lnd-ltc $SYNCINFO |grep 'block_height'|awk '{ print $2 }') )


  while [[ ${xa_xsn::-1} == "false" ]] || [[ ${xb_xsn::-1} == "false" ]] || [[ ${xa_ltc::-1} == "false" ]] || [[ ${xb_ltc::-1} == "false" ]]
  do

    echo -ne "═══════════════════════════
Synchronisation Time: $(date)
Waiting for XSN-Lightning Exchange A: Synced to chain: ${xa_xsn::-1} (Block height: ${xa_xsn_actBlock::-1})
Waiting for LTC-Lightning Exchange A: Synced to chain: ${xa_ltc::-1} (Block height: ${xa_ltc_actBlock::-1})
Waiting for XSN-Lightning Exchange B: Synced to chain: ${xb_xsn::-1} (Block height: ${xb_xsn_actBlock::-1})
Waiting for LTC-Lightning Exchange B: Synced to chain: ${xb_ltc::-1} (Block height: ${xb_ltc_actBlock::-1})
═══════════════════════════"\\033[6A\\r

    xa_xsn=$( (xa-lnd-xsn $SYNCINFO |grep 'synced_to_chain'|awk '{ print $2 }') )
    xa_xsn_actBlock=$( (xa-lnd-xsn $SYNCINFO |grep 'block_height'|awk '{ print $2 }') )

    xb_xsn=$( (xb-lnd-xsn $SYNCINFO |grep 'synced_to_chain'|awk '{ print $2 }') )
    xb_xsn_actBlock=$( (xb-lnd-xsn $SYNCINFO |grep 'block_height'|awk '{ print $2 }') )

    xa_ltc=$( (xa-lnd-ltc $SYNCINFO |grep 'synced_to_chain'|awk '{ print $2 }') )
    xa_ltc_actBlock=$( (xa-lnd-ltc $SYNCINFO |grep 'block_height'|awk '{ print $2 }') )

    xb_ltc=$( (xb-lnd-ltc $SYNCINFO |grep 'synced_to_chain'|awk '{ print $2 }') )
    xb_ltc_actBlock=$( (xb-lnd-ltc $SYNCINFO |grep 'block_height'|awk '{ print $2 }') )

    sleep 1
 done
 echo -e "$GREENTICK All lightning daemons synced!"
}

function startLightningDaemons() {
  echo -e "Starting Lightning Daemons - This can take up to a minute.."

  cd $RESOLVERPATH/exchange-a/lnd/xsn/
  nohup ./start.bash &>> ${SCRIPT_XA_XSN_LOGFILE} &
  echo -e "XSN-Exchange A started.."
  sleep 5
  cd $RESOLVERPATH/exchange-b/lnd/xsn/
  nohup ./start.bash &>> ${SCRIPT_XB_XSN_LOGFILE} &
  echo -e "XSN-Exchange B started.."
  sleep 5
  cd $RESOLVERPATH/exchange-a/lnd/ltc/
  nohup ./start.bash &>> ${SCRIPT_XA_LTC_LOGFILE} &
  echo -e "LTC-Exchange A started.."
  sleep 5
  cd $RESOLVERPATH/exchange-b/lnd/ltc/
  nohup ./start.bash &>> ${SCRIPT_XB_LTC_LOGFILE} &
  echo -e "LTC-Exchange B started.."

  cd $RESOLVERPATH/exchange-a/resolver/
  nohup ./start.bash ltc_xsn &>> ${SCRIPT_XA_RESOLVER_LOGFILE} &
  echo -e "Resolver-Exchange A started.."
  sleep 5
  cd $RESOLVERPATH/exchange-b/resolver/
  nohup ./start.bash ltc_xsn &>> ${SCRIPT_XB_RESOLVER_LOGFILE} &
  echo -e "Resolver-Exchange B started.."


  echo -e "Wait 60 seconds..Until all daemons are started."
  sleep 60
}

function checkSyncStatus() {
 echo -e "Waiting until all core wallets are synchronized!"

  xsn_actBlock=$( ($XSN_CONFIGFOLDER/$XSN_CLIENT $BLOCKCHAININFO |grep 'blocks'|awk '{ print $2 }') )
  xsn_maxBlock=$( ($XSN_CONFIGFOLDER/$XSN_CLIENT $BLOCKCHAININFO |grep 'headers'|awk '{ print $2 }') )
  xsn_numCon=$( ($XSN_CONFIGFOLDER/$XSN_CLIENT $NETWORKINFO |grep 'connections'|awk '{ print $2 }') )

  ltc_actBlock=$( ($LTC_CONFIGFOLDER/$LTC_CLIENT $BLOCKCHAININFO |grep 'blocks'|awk '{ print $2 }') )
  ltc_maxBlock=$( ($LTC_CONFIGFOLDER/$LTC_CLIENT $BLOCKCHAININFO |grep 'headers'|awk '{ print $2 }') )
  ltc_numCon=$( ($LTC_CONFIGFOLDER/$LTC_CLIENT $NETWORKINFO |grep 'connections'|awk '{ print $2 }') )

  while [ ${xsn_maxBlock::-1} -eq 0 ] || [ ${xsn_actBlock::-1} -ne ${xsn_maxBlock::-1} ] || [ ${ltc_maxBlock::-1} -eq 0 ] || [ ${ltc_actBlock::-1} -ne ${ltc_maxBlock::-1} ]
  do

    echo -ne "═══════════════════════════
Synchronisation Time: $(date)
Waiting for XSN sync (${xsn_numCon::-1} Connections): ${xsn_actBlock::-1} / ${xsn_maxBlock::-1} ..
Waiting for LTC sync (${ltc_numCon::-1} Connections): ${ltc_actBlock::-1} / ${ltc_maxBlock::-1} ..
═══════════════════════════"\\033[4A\\r

    xsn_actBlock=$( ($XSN_CONFIGFOLDER/$XSN_CLIENT $BLOCKCHAININFO |grep 'blocks'|awk '{ print $2 }') )
    xsn_maxBlock=$( ($XSN_CONFIGFOLDER/$XSN_CLIENT $BLOCKCHAININFO |grep 'headers'|awk '{ print $2 }') )
    xsn_numCon=$( ($XSN_CONFIGFOLDER/$XSN_CLIENT $NETWORKINFO |grep 'connections'|awk '{ print $2 }') )

    ltc_actBlock=$( ($LTC_CONFIGFOLDER/$LTC_CLIENT $BLOCKCHAININFO |grep 'blocks'|awk '{ print $2 }') )
    ltc_maxBlock=$( ($LTC_CONFIGFOLDER/$LTC_CLIENT $BLOCKCHAININFO |grep 'headers'|awk '{ print $2 }') )
    ltc_numCon=$( ($LTC_CONFIGFOLDER/$LTC_CLIENT $NETWORKINFO |grep 'connections'|awk '{ print $2 }') )

    sleep 1
   done
   echo -e ""
   echo -e "$GREENTICK Wallet synchronisation finished!"
}

function printNetworkStatus() {
  checkIfCoreWalletIsUpStatus $XSN_DAEMON $XSN_CODE_NAME $XSN_CONFIGFOLDER $XSN_CLIENT
  checkIfCoreWalletIsUpStatus $LTC_DAEMON $LTC_CODE_NAME $LTC_CONFIGFOLDER $LTC_CLIENT

  checkIfLNDWalletIsUpStatus "Exchange A XSN" xa-lnd-xsn
  checkIfLNDWalletIsUpStatus "Exchange B XSN" xb-lnd-xsn
  checkIfLNDWalletIsUpStatus "Exchange A LTC" xa-lnd-ltc
  checkIfLNDWalletIsUpStatus "Exchange B LTC" xb-lnd-ltc

  checkIFResolverAreRunning "xsn localhost:10003" "Exchange A"
  checkIFResolverAreRunning "xsn localhost:20003" "Exchange B"
}

function checkIfCoreWalletIsUpStatus() {
  #PARAMS
  # 1:COIN_DAEMON, 2:COIN_NAME, 3:COIN_CONFIGFOLDER, 4:COIN_CLIENT
  if [[ -z "$(ps axo cmd:100 | egrep "$1" | grep ^[^grep])" ]]; then
    echo -e "${RED}ERROR:${OFF} $2 wallet is not runnning."
  else
    actBlock=$( ($3/$4 $BLOCKCHAININFO |grep 'blocks'|awk '{ print $2 }') )
    maxBlock=$( ($3/$4 $BLOCKCHAININFO |grep 'headers'|awk '{ print $2 }') )

    echo -e "${GREENTICK} $2 wallet is runnning - ${actBlock::-1} / ${maxBlock::-1}"
  fi
}

function checkIfLNDWalletIsUpStatus() {
  #PARAMS
  # 1:Tag to Search, 2:alias
  if [[ -z "$(ps axo cmd:100 | egrep "$1" | grep ^[^grep])" ]]; then
    echo -e "${RED}ERROR:${OFF} $1 daemon is not runnning."
  else
    actBlock=$( ($2 $SYNCINFO |grep 'block_height'|awk '{ print $2 }') )
    isSynced=$( ($2 $SYNCINFO |grep 'synced_to_chain'|awk '{ print $2 }') )

    echo -e "${GREENTICK} $1 daemon is runnning - Actual block: ${actBlock::-1} - Synced to chain: ${isSynced::-1}"
  fi
}

function checkIFResolverAreRunning() {
  #PARAMS
  #1: Tag to Search, 2: Tag to Print
  if [[ -z "$(ps axo cmd:100 | egrep "$1" | grep ^[^grep])" ]]; then
    echo -e "${RED}ERROR:${OFF} $2 resolver is not runnning."
  else
    echo -e "${GREENTICK} $2 resolver is runnning."
  fi
}

function outro() {
  clear
  showName
  echo -e "${GREENTICK} Setup finished. Now you have to wait until the chains are synced. Then you can do lightning and atomic swaps!"
  echo -e "To now exactly when it is finished, start this script again and choose \"Check sync and network status..\""
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
  if [[ ! -d $( eval echo "$SCRIPT_LOGFOLDER" ) ]]; then
    mkdir $( eval echo $SCRIPT_LOGFOLDER )
  fi
  #clear
  showName
  checks

  echo -e "Lightning and atomic swaps script $SCRIPTVER (from Denon)"
  echo -e "Log files can be found in $SCRIPT_LOGFOLDER"
  echo -e "════════════════════════════"
  echo -e "══════════ Menu ════════════"
  echo -e "════════════════════════════"

  echo -e "════════════════════════════"
  echo -e "1: Install full setup"
  echo -e "2: Start lightning network (Self-Swap)"
  echo -e "3: Start lightning network (Swap with partner)"
  echo -e "4: Check network status"
  echo -e "5  Stop all the lightning daemons"
  echo -e "6: Exit"
  echo -e "════════════════════════════"

  #PS3="Ihre Wahl : "
  read -rp "Please select your choice: " opt
  case $opt in
  "1") echo -e "Install full setup.."
     doFullSetup
  ;;
  "2") echo -e "Start lightning network.."
    doLightningNetwork
  ;;
  "3") echo -e "Start lightning network.."
    doLightningNetworkWithPartner
  ;;
  "4") echo -e "Check sync and network status.."
    printNetworkStatus
  ;;
  "5") echo -e "Stopping all lightning daemons.."
    ps aux | grep -ie lnd | awk '{print $2}' | xargs kill -9 &>> ${SCRIPT_INTERNAL_LOGFILE}
  ;;
  "6") exit
  ;;

  *) echo -e "${RED}ERROR:${OFF} Invalid option";;
   esac
}

menu
