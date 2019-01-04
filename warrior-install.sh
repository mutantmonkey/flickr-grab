#!/bin/bash

echo "Installing warcio"
if ! sudo pip install warcio --upgrade
then
  exit 1
fi

exit 0

