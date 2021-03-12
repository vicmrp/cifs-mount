#!bin/bash

# Dette scripts formål er til at installere cifs opsætning til en windows server
# navne konvention
# <fqdn>-<cifs_login>-<uid>-<gid>-<netværksmappe>

# Tilføj:
# sudo apt install -y cifs-utils
# hvis det ikke er installeret

# syntax eksempel
# [[ -n $var ]]  # True if the length of $var is non-zero
# [[ -z $var ]]  # True if zero length

# bash mount.sh --server "FQDN" --share "some/shared/folder" --username "user with rights" --uid "33" --gid "33"


# Kræver sudo rettigheder
if [[ $UID != 0 ]]; then
    echo "Please run this script with sudo:"
    echo "sudo $0 $*"
    exit 1
fi

back_to_where_i_was=$(pwd)

my_date () {
  local func_result="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "$func_result"
}

while [ $# -gt 0 ]; do

    if [[ $1 == *"--"* ]]
    then
        param="${1/--/}"
        declare $param="$2"
        # echo $param $1 $2 # Optional to see the parameter:value result
    fi

  shift 1 # rykker positionelle parameter en gang til venstre
done


#
# sørger for at ønskede parameter er indtastet
#
if [[ -z "$server" ]]; then echo "Please specify '--server'"; exit 1; fi;
if [[ -z "$share" ]]; then echo "Please specify '--share'. e.g home/www-data"; exit 1; fi; sharename="$(echo "$share" | sed 's/\//_/g')"
if [[ -z "$username" ]]; then echo "Please specify '--username'"; exit 1; fi;
if [[ -z "$uid" ]]; then echo "Please specify '--uid'"; exit 1; fi;
if [[ -z "$gid" ]]; then echo "Please specify '--gid'"; exit 1; fi;

mount=$(echo $server-$username-$uid-$gid-$sharename | sed 's/\$//g')

echo "Please enter your password"; read -s password

# sudo apt update && sudo apt install -y cifs-utils

# minder dig om at cifs skal installeres først og at du skal sørge for at mapperne ikke eksistere i forvejen.
if [[ -z "$force" ]] 
then 

    echo "Did you make sure that you have installed cifs-utils before running this script? ['sudo apt update && sudo apt install -y cifs-utils']";
    echo "To continue write 'continue' or use the force parameter [--force true]. Type exit to and hit enter"
    while read continue_or_exit
    do
        if [[ $continue_or_exit == "continue" ]]; then

            echo "$(my_date) Proceeding..." >> mount.log
            sleep 1
            break

        elif [[ $continue_or_exit == "exit" ]]; then

            echo "$(my_date) Exiting safely..." >> mount.log
            exit 1
        
        else 

            echo "$(my_date) Please type 'continue' or 'exit'" >> mount.log

        fi
    done

    echo "Please make sure that you have no mount share active. hence run 'sudo umount -a' before continueing";
    echo "To continue write 'continue' or use the force parameter [--force true]. "
    echo "Type exit and hit enter to exit"
    while read continue_or_exit
    do
        if [[ $continue_or_exit == "continue" ]]; then

            echo "$(my_date) Proceeding..." >> mount.log
            sleep 1
            break

        elif [[ $continue_or_exit == "exit" ]]; then

            echo "$(my_date) Exiting safely..." >> mount.log
            exit 1
        
        else 

            echo "$(my_date) Please type 'continue' or 'exit'" >> mount.log

        fi
    done
fi;

# <fqdn>-<cifs_login>-<uid>-<gid>-<netværksmappe>
echo "$(my_date) server name is: $server" >> mount.log

echo "$(my_date) user cifs user: $username" >> mount.log

echo "$(my_date) the path on the server is: $share" >> mount.log
 
echo "$(my_date) uid: $uid, gid: $gid" >> mount.log

echo "$(my_date) the name of mount point is: $mount" >> mount.log

# unmounter det hele
echo "STARTER unmounter det hele" >> mount.log
umount -a 2> /dev/null

# tjæk om mountpointet allerede er i brug.
echo 'Starter først læs fstab og udkommenter eventuelle tidligere forbindelser til serveren'

# Sørger for at der ikke er dubletter
cd /root; rm -f temp_vezit; touch temp_vezit

while read p; do

    if [[ $p == *"$mount"* ]] && [[ $p != *"#//$server"* ]]; then
        echo "#$p" >> temp_vezit
        echo "$(my_date) mountet var allerede i brug" >> "$back_to_where_i_was/mount.log"
    else 
        echo "$p" >> temp_vezit
    fi

done </etc/fstab


cat temp_vezit > /etc/fstab
rm temp_vezit 2> /dev/null

# tilføjer til fstab
echo "//$server/$share /mnt/$mount cifs uid=$uid,gid=$gid,forceuid,forcegid,credentials=/root/.smb/.$username,vers=2.0,noperm 0 0" >> /etc/fstab

# skaber mount point 
cd /mnt
mkdir -p "$mount"


# fjerner nådest løst tidligere credentials hvis de hedder det samme
cd /root/.smb
rm -f ".$username"; 
touch ".$username"; 
echo "user=$username" >> ".$username"
echo "password=$password" >> ".$username"

echo "STARTER laver .smb mappe 700 rettigheder" 
cd /root
mkdir -p .smb
chmod -R 700 .smb
cd /root/.smb


# mounter det hele
echo 'STARTER mount -a'
mount -a
cd $back_to_where_i_was

echo '' > mount-temp.txt
cat /etc/fstab > mount-temp.txt
