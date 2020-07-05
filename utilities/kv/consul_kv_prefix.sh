#!/bin/bash

# The "ctn" and "ctp" scripts are plugin scripts for consul-template. They simply add a CTN_PREFIX or CTP_PREFIX to
# a KV key. Using a plugin script is a lot cleaner than doing:  "{{ printf "%s/node-ip" (env "CTN_PREFIX") | key }}"
# Additionally this script waits up to 7 seconds if the key is not found and falls back by writing
# an error to syslog and returning a blank string.

PREFIX=$1
SUFFIX=$2

SUFFIX_CHAR_0=$(echo $SUFFIX | cut -c1-1)

if [[ $SUFFIX_CHAR_0 != "/" ]]
then
  SUFFIX="/$SUFFIX"
fi


# add prefix to key
KEY="$PREFIX$SUFFIX"


for ((n=0;n<7;n++))
do
  RESULT="$(consul kv get $KEY 2>&1)"
  RESULT_LOWERCASE="${RESULT,,}"

  if [[ ! "$RESULT_LOWERCASE" =~ ^error.* ]]
    then
      # key found, return value  (todo: what if the value starts with string "error"?)
      echo $RESULT
      exit 0
  fi

  sleep 1
done


# write error to syslog
echo "error: consul_kv_prefix.sh: $RESULT" | logger

# return blank string to consul-template
echo ""
exit 0
