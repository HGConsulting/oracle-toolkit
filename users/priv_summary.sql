/* priv_summary.sql

It shows a brief summary of the privileges a user have
the script traverse across all roles and displays if it
has READ or WRITE access to any schema

Esteban Fajardo Bravo
(efajardx@outlook.com)
*/

SET VERIFY OFF SERVEROUTPUT ON
DECLARE
  l_username     VARCHAR2(30) := UPPER('&1.');
  USER_NOT_FOUND EXCEPTION
BEGIN
  dbms_output.put_line('Privileges');
  dbms_output.put_line('----------');
  $if dbms_db_version.ver_le_10_2 $THEN
    null; -- Unsupported on 10gR2 downwards (yet)
  $else
  FOR c_r IN ( WITH c_flatroles (grantee, granted_role )
                 AS ( SELECT 'ROOT' as grantee,
				             l_username as granted_role
						FROM dual
                        UNION ALL
                        SELECT rp2.grantee,
                               rp2.granted_role
                          FROM dba_role_privs rp2
                         INNER JOIN c_flatroles rp1 ON (rp1.granted_role = rp2.grantee)
                    )
             SELECT owner,
                    listagg(priv,',') WITHIN GROUP (ORDER BY priv) as privs
               FROM ( SELECT tp.owner,
                             CASE WHEN tp.privilege IN ('SELECT','EXECUTE') THEN 'READ'
                                  WHEN tp.privilege IN ('ALTER') AND obj.object_type IN ('SEQUENCE') THEN 'ALTSEQ'
                                  ELSE 'WRITE'
                             END as priv
                        FROM c_flatroles fr
                       INNER JOIN dba_tab_privs tp ON (tp.grantee = ft.granted_role)
                       INNER JOIN dba_objects obj ON (obj.object_name = tp.table_name AND obj.owner = tp.owner)
                       WHERE tp.owner NOT IN ('SYS','SYSTEM','APPQOSSYS','PERFSTAT','TOAD','OUTLN','TEMPDBA','DBSNMP')
                       GROUP BY tp.owner,
                                CASE WHEN tp.privilege IN ('SELECT','EXECUTE') THEN 'READ'
                                     WHEN tp.privilege IN ('ALTER') AND obj.object_type IN ('SEQUENCE') THEN 'ALTSEQ'
                                     ELSE 'WRITE'
                                END
                    )
               GROUP BY owner
             )
  LOOP
    dbms_output.put_line(c_r.owner || ' ' || c_r.privs);
  END LOOP;
  $end
EXCEPTION
  WHEN user_not_found THEN
    dbms_output.put_line('User ' || l_username || ' does not exist!');
END;
/
