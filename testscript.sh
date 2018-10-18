#!/bin/bash
#LTC_RPC_USER='Litecoin'
#sed -i 's/user=xu/user="$LTC_RPC_USER"/g' ~/test.conf
#sed -i "s|user=xu|user=$LTC_RPC_USER|g" ~/test.conf

LNDPATH="$HOME/lnd"

echo -e "alias xa-lnd-xsn='$LNDPATH/lncli --network $NETWORK --rpcserver=localhost:10003 --no-macaroons' " >> ~/Downloads/test.conf
echo -e "alias xa-lnd-ltc='$LNDPATH/lncli --network $NETWORK --rpcserver=localhost:10001 --no-macaroons' " >> ~/Downloads/test.conf
echo -e "alias xb-lnd-xsn='$LNDPATH/lncli --network $NETWORK --rpcserver=localhost:20003 --no-macaroons' " >> ~/Downloads/test.conf
echo -e "alias xb-lnd-ltc='$LNDPATH/lncli --network $NETWORK --rpcserver=localhost:20001 --no-macaroons' " >> ~/Downloads/test.conf
