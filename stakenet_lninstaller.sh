#!/bin/bash
SCRIPTVER=1.0.1

WALLET_TIMEOUT_S=60
NETWORK=""

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
XSN_COIN_GIT='https://github.com/X9Developers/lnd/raw/master/wallets/xsn-1.0.16-x86_64-linux-gnu.tar.gz'
XSN_FILE_NAME_TAR='xsn-1.0.16-x86_64-linux-gnu.tar.gz'
XSN_FILE_NAME='xsn-1.0.16'
XSN_CONFIGFOLDER="$HOME/.xsncore"
XSN_CONFIG_FILE='xsn.conf'
XSN_RPC_USER=''
XSN_RPC_PASS=''
XSN_ZMQ_BLOCK_PORT='28444'
XSN_ZMQ_TX_PORT='28445'


LNDGIT='https://github.com/X9Developers/swap-resolver/releases/download/v1.0.0'
LNDPATH='$HOME/lndbin'

RESOLVERPATH="$GOPATH/src/github.com/ExchangeUnion/swap-resolver"

#commands
BLOCKCHAININFO='getblockchaininfo'

function doFullSetup() {
  clear
  networkRequest
  installDependencies
  configureGOPath

  installGenWallet $LTC_CODE_NAME $LTC_FILE_NAME_TAR $LTC_FILE_NAME $LTC_CONFIGFOLDER $LTC_COIN_GIT $LTC_DAEMON $LTC_CLIENT
  createGenConfig $LTC_CODE_NAME $LTC_RPC_USER $LTC_RPC_PASS $LTC_CONFIGFOLDER $LTC_ZMQ_BLOCK_PORT $LTC_ZMQ_TX_PORT
  startGenWallet $LTC_CODE_NAME $LTC_CONFIGFOLDER $LTC_DAEMON $LTC_CLIENT

  installGenWallet $XSN_CODE_NAME $XSN_FILE_NAME_TAR $XSN_FILE_NAME $XSN_CONFIGFOLDER $XSN_COIN_GIT $XSN_DAEMON $XSN_CLIENT
  createGenConfig $XSN_CODE_NAME $XSN_RPC_USER $XSN_RPC_PASS $XSN_CONFIGFOLDER $XSN_ZMQ_BLOCK_PORT $XSN_ZMQ_TX_PORT
  startGenWallet $XSN_CODE_NAME $XSN_CONFIGFOLDER $XSN_DAEMON $XSN_CLIENT

  installANDconfigureLNDDeamons
  installANDconfigureSwapResolver
}

function startGenWallet() {
  #PARAMS
  #1:COIN_CODE_NAME, 2:COIN_CONFIGFOLDER, 3:COIN_DAEMON, 4:COIN_CLIENT,
  echo -e "Starting $1 daemon (takes up to $WALLET_TIMEOUT_S seconds).."
  2>/dev/null 1>/dev/null $2/$3

  # WaitOnServerStart
  waitWallet="-1"
  retryCounter=0
  echo -ne "Waiting on $1 wallet${BLINK}..${OFF}"
  while [[ $waitWallet -ne "0" && $retryCounter -lt $WALLET_TIMEOUT_S ]]
  do
    sleep 1
    2>/dev/null 1>/dev/null $2/$4 $BLOCKCHAININFO
    waitWallet="$?"
    retryCounter=$[retryCounter+1]
  done

  echo -e \\r"Waiting on wallet.."
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
  #1:COIN_CODE_NAME, 2:COIN_RPC_USER, 3:COIN_RPC_PASS, 4:COIN_CONFIGFOLDER,5:COIN_ZMQ_BLOCK_PORT, 6:COIN_ZMQ_TX_PORT
  echo -e "Generating $1 config.."

  $2=$(openssl rand -hex 11)
  $3=$(openssl rand -hex 20)

cat << EOF > $(eval echo $3/$4)
  #=========
  rpcallowip=127.0.0.1
  rpcuser=$2
  rpcpassword=$3
  #=========
  zmqpubrawblock=tcp://127.0.0.1:$5
  zmqpubrawtx=tcp://127.0.0.1:$6
  #=========
  listen=1
  server=1
  daemon=1
  $NETWORK=1
  #=========

EOF
  echo -e "$GREENTICK Finished $1 config configuration!"
}

function installGenWallet() {
  #PARAMS
  # 1:COIN_CODE_NAME, 2:COIN_FILE_NAME_TAR, 3:COIN_FILE_NAME, 4:COIN_CONFIGFOLDER, 5:COIN_GIT, 6:COIN_DAEMON, 7:COIN_CLIENT
  echo -e "Downloading and installing $1 daemon.."
  rm -rf $2*

  if [[ ! -d $( eval echo "$4" ) ]]; then
    mkdir $( eval echo $4 )
  fi

  wget --progress=bar:force $5 2>&1 | progressfilt
  if [ $? -ne 0 ]
  then
    echo -e "${RED}ERROR:${OFF} Failed to download $5!"
    exit
  fi

  tar xfvz $2*  > /dev/null 2>&1
  if [ $? -ne 0 ]
  then
    echo -e "${RED}ERROR:${OFF} Failed to unzip $2!"
    exit
  fi

  cp $3/bin/$6 $4 > /dev/null 2>&1
  cp $3/bin/$7 $4 > /dev/null 2>&1
  chmod 777 $4/$6
  chmod 777 $4/$7

  #Clean up
  rm -rf $3*

  echo -e "$GREENTICK $1 daemon installation done!"
}

function installANDconfigureLNDDeamons() {
  mkdir $LNDPATH
  wget $LNDGIT/lncli -P $LNDPATH
  wget $LNDGIT/lnd -P $LNDPATH
  wget $LNDGIT/lnd_xsn -P $LNDPATH

  chmod 777 $LNDPATH/ln*

  # Adding lncli aliases
  echo -n "alias xa-lnd-xsn='$LNDPATH/lncli --network $NETWORK --rpcserver=localhost:10003 --no-macaroons' " >> ~/.profile
  echo -n "alias xa-lnd-ltc='$LNDPATH/lncli --network $NETWORK --rpcserver=localhost:10001 --no-macaroons' " >> ~/.profile
  echo -n "alias xb-lnd-xsn='$LNDPATH/lncli --network $NETWORK --rpcserver=localhost:20003 --no-macaroons' " >> ~/.profile
  echo -n "alias xb-lnd-ltc='$LNDPATH/lncli --network $NETWORK --rpcserver=localhost:20001 --no-macaroons' " >> ~/.profile
  source ~/.profile
}

function installANDconfigureSwapResolver() {
  echo -e "Installing Swap-Resolver.."
  git clone https://github.com/X9Developers/swap-resolver.git $GOPATH/src/github.com/ExchangeUnion/swap-resolver

  # Set rpcUserPass LTC
  sed -i "s|user=xu|user=$XSN_RPC_USER|g" $RESOLVERPATH/exchange-a/lnd/ltc/start.bash
  sed -i "s|pass=xu|pass=$XSN_RPC_PASS|g" $RESOLVERPATH/exchange-a/lnd/ltc/start.bash

  sed -i "s|user=xu|user=$XSN_RPC_USER|g" $RESOLVERPATH/exchange-b/lnd/ltc/start.bash
  sed -i "s|pass=xu|pass=$XSN_RPC_PASS|g" $RESOLVERPATH/exchange-b/lnd/ltc/start.bash

  ## Set network LTC
  sed -i "s|testnet|$NETWORK|g" $RESOLVERPATH/exchange-a/lnd/ltc/start.bash
  sed -i "s|testnet|$NETWORK|g" $RESOLVERPATH/exchange-b/lnd/ltc/start.bash

  ### Set daemon LTC
  sed -i "s|lnd|$LNDPATH/lnd|g" $RESOLVERPATH/exchange-a/lnd/ltc/start.bash
  sed -i "s|lnd|$LNDPATH/lnd|g" $RESOLVERPATH/exchange-b/lnd/ltc/start.bash

  # Set rpcUserPass XSN
  sed -i "s|user=xu|user=$XSN_RPC_USER|g" $RESOLVERPATH/exchange-a/lnd/xsn/start.bash
  sed -i "s|pass=xu|pass=$XSN_RPC_PASS|g" $RESOLVERPATH/exchange-a/lnd/xsn/start.bash

  sed -i "s|user=xu|user=$XSN_RPC_USER|g" $RESOLVERPATH/exchange-b/lnd/xsn/start.bash
  sed -i "s|pass=xu|pass=$XSN_RPC_PASS|g" $RESOLVERPATH/exchange-b/lnd/xsn/start.bash

  ## Set network XSN
  sed -i "s|testnet|$NETWORK|g" $RESOLVERPATH/exchange-a/lnd/xsn/start.bash
  sed -i "s|testnet|$NETWORK|g" $RESOLVERPATH/exchange-b/lnd/xsn/start.bash

  ### Set daemon XSN
  sed -i "s|lnd|$LNDPATH/lnd_xsn|g" $RESOLVERPATH/exchange-a/lnd/xsn/start.bash
  sed -i "s|lnd|$LNDPATH/lnd_xsn|g" $RESOLVERPATH/exchange-b/lnd/xsn/start.bash
}

# ToDo Was machen wenn es schon drin ist?
function configureGOPath() {
    echo -n "export GOPATH=$HOME/go" >> ~/.bashrc
    echo -n "export PATH=/usr/local/go/bin:$GOPATH/bin:$PATH" >> ~/.bashrc
    source ~/.bashrc
}

function installDependencies() {
    echo -ne "Installing dependencies${BLINK}..${OFF}"
    echo "y" | apt update > /dev/null 2>&1
    echo "y" | apt upgrade > /dev/null 2>&1
    echo "y" | apt install -y ufw python virtualenv git unzip pv golang-go > /dev/null 2>&1
    echo -e \\r"Installing dependencies.."
    echo -e "$GREENTICK Dependency install done!"
}

function networkRequest() {
  echo -e "Which network should be used?"
  echo -e "1: Mainnet"
  echo -e "2: Testnet"

  read -rp "" opt
  case $opt in
    "1") echo -e "Mainnet Let's do it"
         NETWORK='mainnet'
    ;;
    "2") echo -e "Testnet Let's do it"
         NETWORK='testnet'
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
  if [[ $( lsb_release -d ) != *16.04* ]]; then
    echo -e "${RED}ERROR:${OFF} You are not running Ubuntu 16.04. Installation is cancelled."
    exit 1
  fi

  if [[ $EUID -ne 0 ]]; then
     echo -e "${RED}ERROR:${OFF} Must be run as root (try \"sudo $SCRIPT_NAME\" )"
     exit 1
  fi
}

function menu() {
  clear
  #checks

  echo -e "Lightning & Atomic Swaps script $SCRIPTVER (from Denon)"
  echo -e "════════════════════════════"
  echo -e "══════════ Menu ════════════"
  echo -e "════════════════════════════"

  echo -e "════════════════════════════"
  echo -e "1: Install full setup"
  echo -e "2: tbd"
  echo -e "3: tbd"
  echo -e "4: Exit"
  echo -e "════════════════════════════"

  #PS3="Ihre Wahl : "
  read -rp "Please select your choice: " opt
  case $opt in
    "1") echo -e "Install full setup.."
         doFullSetup
    ;;
    "2") echo -e "tbd"

    ;;
    "3") echo -e "tbd"

    ;;

    "4") exit
    ;;

    *) echo -e "${RED}ERROR:${OFF} Invalid option";;
   esac
}

menu
