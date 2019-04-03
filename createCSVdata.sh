#!/bin/bash
# Create a bunch of random CSV data in a directory

mkdir data

for value in {1..100}
do
  randomno=$((RANDOM%3))
  sleep $randomno
  runtime=`date +"%F-%T"`
  echo "date, delay" > ./data/$runtime.csv
  echo "$runtime, $randomno" >> ./data/$runtime.csv
done
