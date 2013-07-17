#!/bin/bash

if [ $# -ne 2 ];
then
    echo "Syntax: $0 zonename command"
    echo "Example : $0 domain.tld genkeys"
    echo "Example : $0 domain.tld sign"
    echo "Example : $0 domain.tld clean"
    exit
elif [ -f "$1.hosts" ];
then
    #Values used to sign/clean
    ZONE=$1
    KEYSPATH="${ZONE}_dnssec"
    FILE="${ZONE}.hosts"
    DATE=`date +%e-%m-%y`
    if [ "genkeys" = $2 ];
    then
        #Test if directory exists
        if [ ! -d "${KEYSPATH}" ];
        then
            mkdir -p $KEYSPATH
        fi  

        #GENERATING Key pairs for ZSK and KSK
        ZSK=$(dnssec-keygen -r /dev/urandom -K $KEYSPATH -a RSASHA1 -b 1024 -n ZONE ${ZONE})
        KSK=$(dnssec-keygen -r /dev/urandom -K $KEYSPATH -a RSASHA1 -b 4096 -n ZONE -f KSK ${ZONE})
    
        echo "=>>> ZSK :  ${ZSK}"
        echo "=>>> KSK :  ${KSK}"
    
        #KEY INFOS LOG
        echo -e "--- ${DATE} (ZSK KSK) ---\t${ZSK}\t${KSK}" >> "${KEYSPATH}/gen_infos.txt"
    
        #CHANGING OWNERSHIP of the key to user named
        chown named:named ${KEYSPATH}/*
    
        #ADDING KEY KSK & ZSK to the zone
        echo "\$INCLUDE \"$KEYSPATH/$KSK.key\"" >> $FILE
        echo "\$INCLUDE \"$KEYSPATH/$ZSK.key\"" >> $FILE
    
    elif [ "sign" = $2 ];
    then
        #CHECK THE KEY
        RZSK=`sed '$!d' ${KEYSPATH}/gen_infos.txt | cut -f2 `
        RKSK=`sed '$!d' ${KEYSPATH}/gen_infos.txt | cut -f3 `
    
        echo "FOUND KEYS"
        echo "ZSK: ${RZSK}"
        echo "KSK: ${RKSK}"
    
        #ADDING KEY KSK & ZSK to the zone
        echo "ADDING KSK & ZSK keys to the zone"
        echo "\$INCLUDE \"$KEYSPATH/$RKSK.key\"" >> $FILE
        echo "\$INCLUDE \"$KEYSPATH/$RZSK.key\"" >> $FILE

        #SIGNING THE ZONE
        dnssec-signzone -t -p -e +31536000 -o ${ZONE} -N increment -k "${KEYSPATH}/$RKSK.key" $FILE "${KEYSPATH}/$RZSK.key"
    
    elif [ "clean" = $2 ];
    then
        rm "${FILE}.signed"
        echo "${FILE}.signed deleted"

        sed -n '/\$INCLUDE ".*"/d' ${FILE}
        echo "INCLUDES IN ${FILE} removed"

        rm "dsset-${ZONE}."
        echo "dsset-${ZONE}. deleted"                 
    else
        echo "Syntax: $0 zonename command"
        echo "Example : $0 domain.tld (genkeys|sign|clean)"
        exit
    fi
else
    echo "$1.hosts not found"
    exit
fi
