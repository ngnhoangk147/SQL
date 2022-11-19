set wrap off
set lines 155
set pages 0
set feedback off
set verify off    
set trimspool on  
set termout off   
spool accountinfo_today.csv
select a.identify||','||b.name||','||c.USCREDVO from ppm a inner join servclas b on a.servclas = b.ri inner join credit c on a.ri=c.ri where rownum<1000;
spool off;
exit
