#!/bin/bash

./hugo
if [ $? -eq 0 ]; then
  rsync -vhza public/* drpaneas@n1nlhftpg030.shr.prod.ams1.secureserver.net:html
  exit 0
else
  exit 1
fi
