##!/bin/bash
#LTC_RPC_USER='Litecoin'
#sed -i 's/user=xu/user="$LTC_RPC_USER"/g' ~/test.conf
#sed -i "s|user=xu|user=$LTC_RPC_USER|g" ~/test.conf



function test() {

  if [ -z "$1" ]; then
      echo "You need to supply a search string..."
  else
      processes=$(ps aux | grep $1 -i | awk -F ' ' '{print $2}' | xargs)
      echo "Processes: "$processes
      while true; do
          read -ep "Are you sure you want kill all '$1' processes? [y/N] " yesno
          case $yesno in
              [Yy]* )
                  echo 'Killing processes...'
                  for i in $processes; do kill $i; done
                  echo "Processes Killed: " $processes
                  break;;
              * )
                  echo "Skipped killing processes..."
                  break;;
          esac
      done
  fi
}


#echo -e "export GOPATH=$HOME/go" >> ~/Downloads/test.conf
#echo -e "export PATH=/usr/bin/go/bin:$GOPATH/bin:$PATH" >> ~/Downloads/test.conf



sed -i '/GOPATH/d' ~/Downloads/test.conf
sed -i '/go/d' ~/Downloads/test.conf
