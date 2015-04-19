#!/bin/bash

git add --all
MESSAGE=$(date)
git commit -m "$MESSAGE"
git push

