#!/bin/sh

echo "Script generated."
echo "Collecting data..."

export ORACLE_SID=PSMF
sqlplus user/pass @test_select_accountinfo.sql
echo "Subscriber,Profile,Amount" > accountinfo.csv
cat accountinfo_today.csv >> accountinfo.csv
mv accountinfo.csv accountinfo_`date +"%H%M_%d%m"`.csv
rm accountinfo_today.csv
echo "Collecting done."

