##!/bin/bash
#LTC_RPC_USER='Litecoin'
#sed -i 's/user=xu/user="$LTC_RPC_USER"/g' ~/test.conf
#sed -i "s|user=xu|user=$LTC_RPC_USER|g" ~/test.conf
EXCHANGE='B'

if [ "$EXCHANGE" == "A" ]; then
  echo "A"
fi

if [ "$EXCHANGE" == "B" ]; then
  echo "B"
fi
