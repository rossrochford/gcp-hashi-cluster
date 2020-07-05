#!/bin/bash

# get the total combined Mhz frequency of all cpu cores and the available memory in megabytes


CPU_CORE_MHZ=$(cat /proc/cpuinfo | grep MHz | cut -d' ' -f3 | tr '\r\n' ' ')

TOTAL_MHZ=0

for mhz in $CPU_CORE_MHZ; do
  mhz_int=${mhz%.*}
  ((TOTAL_MHZ=TOTAL_MHZ+mhz_int))
done

# get available memory from row 4 column 4
MEMORY_AVAILABLE=$(free --mega -t | sed -n 4p | awk '{print $4}')


echo "$TOTAL_MHZ $MEMORY_AVAILABLE"
