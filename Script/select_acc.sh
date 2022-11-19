#!/bin/sh

echo "Script generated."
echo "Collecting data..."
echo "set wrap off" > test_select_accountinfo.sql
echo "set lines 155" >> test_select_accountinfo.sql
echo "set pages 0" >> test_select_accountinfo.sql
echo "set head off" >> test_select_accountinfo.sql
echo "set feedback off" >> test_select_accountinfo.sql
echo "spool accountinfo_today.csv" >> test_select_accountinfo.sql
echo "a.identify||','||b.name||','||c.USCREDVO from ppm a inner join servclas b on a.servclas = b.ri inner join credit c on a.ri=c.ri where rownum<1000;" >> test_select_accountinfo.sql
echo "spool off;" >> test_select_accountinfo.sql
echo "exit" >> test_select_accountinfo.sql
export ORACLE_SID=PSMF
sqlplus user/pass @test_select_accountinfo.sql
cat accountinfo_today.csv >> accountinfo.csv
mv accountinfo.csv accountinfo_`date +"%H%M_%d%m"`.csv
rm accountinfo_today.csv
echo "Collecting done."

