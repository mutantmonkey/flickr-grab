#!/bin/bash

echo "Installing warc"
if ! sudo pip install warc
then
  exit 1
fi

exit 0

