#!/bin/sh

echo "Script generated."
echo "Collecting data..."
echo "set wrap off" > select_account.sql
echo "set lines 155" >> select_account.sql
echo "set pages 0" >> select_account.sql
echo "set head off" >> select_account.sql
echo "set feedback off" >> select_account.sql
echo "spool accountinfo_today.csv" >> select_account.sql
echo "select a.identify||','||b.name||','||a.ACCREDDT from ppm a inner join servclas b on a.servclas = b.ri where rownum<1000;" >> select_account.sql
echo "spool off;" >> select_account.sql
echo "exit" >> select_account.sql
export ORACLE_SID=PSMF
sqlplus user/pass @test_select_accountinfo.sql
cat accountinfo_today.csv >> accountinfo.csv
mv accountinfo.csv accountinfo_`date +"%H%M_%d%m"`.csv
rm accountinfo_today.csv
echo "Collecting done."

