#!/bin/bash
SCRIPTVER=1.0.1

#Litecoin
LTC_CODE_NAME='LTC'
LTC_COIN_GIT='https://download.litecoin.org/litecoin-0.16.3/linux/litecoin-0.16.3-x86_64-linux-gnu.tar.gz'
LTC_FILE_NAME_TAR='litecoin-0.16.3-x86_64-linux-gnu.tar.gz'
LTC_FILE_NAME='litecoin-0.16.3'
LTC_CONFIGFOLDER="$HOME/.litecoin"
LTC_CONFIG_FILE='litecoin.conf'
LTC_RPC_USER=''
LTC_RPC_PASS=''

#Stakenet
XSN_CODE_NAME='XSN'
XSN_COIN_GIT='TODO'
XSN_FILE_NAME_TAR='TODO'
XSN_FILE_NAME='TODO'
XSN_CONFIGFOLDER="$HOME/.xsncore"
XSN_CONFIG_FILE='xsn.conf'
XSN_RPC_USER=''
XSN_RPC_PASS=''

LNDGIT='https://github.com/X9Developers/swap-resolver/releases/download/v1.0.0'
LNDPATH='$HOME/lndbin'


RESOLVERPATH="$GOPATH/src/github.com/ExchangeUnion/swap-resolver"

function doFullSetup() {
  clear
  installDependencies
  configureGOPath
  installLitecoin
  createLitecoinConfig
  installXsn
  createXsnConfig


}

function installANDconfigureLNDDeamons() {
  mkdir $LNDPATH
  wget $LNDGIT/lncli -P $LNDPATH
  wget $LNDGIT/lnd -P $LNDPATH
  wget $LNDGIT/lnd_xsn -P $LNDPATH

  chmod 777 $LNDPATH/ln*

  # Adding lncli aliases
  echo -n "alias xa-lnd-xsn='$LNDPATH/lncli --network testnet --rpcserver=localhost:10003 --no-macaroons' " >> ~/.profile
  echo -n "alias xa-lnd-ltc='$LNDPATH/lncli --network testnet --rpcserver=localhost:10001 --no-macaroons' " >> ~/.profile
  echo -n "alias xb-lnd-xsn='$LNDPATH/lncli --network testnet --rpcserver=localhost:20003 --no-macaroons' " >> ~/.profile
  echo -n "alias xb-lnd-ltc='$LNDPATH/lncli --network testnet --rpcserver=localhost:20001 --no-macaroons' " >> ~/.profile
  source ~/.profile
}

function installANDconfigureSwapResolver() {
  echo -e "Installing Swap-Resolver.."
  git clone https://github.com/X9Developers/swap-resolver.git $GOPATH/src/github.com/ExchangeUnion/swap-resolver

  # Set rpcUserPass LTC
  sed -i "s|user=xu|user=$XSN_RPC_USER|g" $RESOLVERPATH/exchange-a/lnd/ltc/start.bash
  sed -i "s|pass=xu|user=$XSN_RPC_PASS|g" $RESOLVERPATH/exchange-a/lnd/ltc/start.bash

  sed -i "s|user=xu|user=$XSN_RPC_USER|g" $RESOLVERPATH/exchange-b/lnd/ltc/start.bash
  sed -i "s|pass=xu|user=$XSN_RPC_PASS|g" $RESOLVERPATH/exchange-b/lnd/ltc/start.bash

  # Set rpcUserPass XSN
  sed -i "s|user=xu|user=$XSN_RPC_USER|g" $RESOLVERPATH/exchange-a/lnd/xsn/start.bash
  sed -i "s|pass=xu|user=$XSN_RPC_PASS|g" $RESOLVERPATH/exchange-a/lnd/xsn/start.bash

  sed -i "s|user=xu|user=$XSN_RPC_USER|g" $RESOLVERPATH/exchange-b/lnd/xsn/start.bash
  sed -i "s|pass=xu|user=$XSN_RPC_PASS|g" $RESOLVERPATH/exchange-b/lnd/xsn/start.bash
}


function createXsnConfig() {
  echo -e "Generating $XSN_CODE_NAME config.."

  XSN_RPC_USER=$(openssl rand -hex 11)
  XSN_RPC_PASS=$(openssl rand -hex 20)

cat << EOF > $(eval echo $LTC_CONFIGFOLDER/$XSN_CONFIG_FILE)
  #=========
  rpcallowip=127.0.0.1
  rpcuser=$XSN_RPC_USER
  rpcpassword=$XSN_RPC_PASS
  #=========
  zmqpubrawblock=tcp://127.0.0.1:28444
  zmqpubrawtx=tcp://127.0.0.1:28445
  #=========
  listen=1
  server=1
  daemon=1
  #=========

EOF
  echo -e "$GREENTICK Finished $XSN_CONFIG_FILE configuration!"
}

function installXsn() {
  echo -e "Downloading and installing XSN daemon.."
  rm -rf $XSN_FILE_NAME_TAR*

  if [[ ! -d $( eval echo "$XSN_CONFIGFOLDER" ) ]]; then
    mkdir $( eval echo $XSN_CONFIGFOLDER )
  fi

  wget --progress=bar:force $XSN_COIN_GIT 2>&1 | progressfilt
  if [ $? -ne 0 ]
  then
    echo -e "${RED}ERROR:${OFF} Failed to download $XSN_COIN_GIT!"
    exit
  fi

  tar xfvz $XSN_FILE_NAME_TAR*  > /dev/null 2>&1
  if [ $? -ne 0 ]
  then
    echo -e "${RED}ERROR:${OFF} Failed to unzip $XSN_FILE_NAME_TAR!"
    exit
  fi

  cp $XSN_FILE_NAME/bin/xsnd $XSN_CONFIGFOLDER > /dev/null 2>&1
  cp $XSN_FILE_NAME/bin/xsn-cli $XSN_CONFIGFOLDER > /dev/null 2>&1
  chmod 777 $XSN_CONFIGFOLDER/xsn*

  #Clean up
  rm -rf $XSN_FILE_NAME*

  echo -e "$GREENTICK XSN daemon installation done!"
}

function createLitecoinConfig() {
  echo -e "Generating $LTC_CODE_NAME config.."

  LTC_RPC_USER=$(openssl rand -hex 11)
  LTC_RPC_PASS=$(openssl rand -hex 20)

cat << EOF > $(eval echo $LTC_CONFIGFOLDER/$LTC_CONFIG_FILE)
  #=========
  rpcallowip=127.0.0.1
  rpcuser=$LTC_RPC_USER
  rpcpassword=$LTC_RPC_PASS
  #=========
  zmqpubrawblock=tcp://127.0.0.1:28332
  zmqpubrawtx=tcp://127.0.0.1:28333
  #=========
  listen=1
  daemon=1
  server=1
  #=========

EOF
  echo -e "$GREENTICK Finished $LTC_CONFIG_FILE configuration!"
}

function installLitecoin() {
  echo -e "Downloading and installing LTC daemon.."
  rm -rf $LTC_FILE_NAME_TAR*

  if [[ ! -d $( eval echo "$LTC_CONFIGFOLDER" ) ]]; then
    mkdir $( eval echo $LTC_CONFIGFOLDER )
  fi

  wget --progress=bar:force $LTC_COIN_GIT 2>&1 | progressfilt
  if [ $? -ne 0 ]
  then
    echo -e "${RED}ERROR:${OFF} Failed to download $LTC_COIN_GIT!"
    exit
  fi

  tar xfvz $LTC_FILE_NAME_TAR*  > /dev/null 2>&1
  if [ $? -ne 0 ]
  then
    echo -e "${RED}ERROR:${OFF} Failed to unzip $LTC_FILE_NAME_TAR!"
    exit
  fi

  cp $LTC_FILE_NAME/bin/litecoind $LTC_CONFIGFOLDER > /dev/null 2>&1
  cp $LTC_FILE_NAME/bin/litecoin-cli $LTC_CONFIGFOLDER > /dev/null 2>&1
  chmod 777 $LTC_CONFIGFOLDER/litecoin*

  #Clean up
  rm -rf $LTC_FILE_NAME*

  echo -e "$GREENTICK LTC daemon installation done!"
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
