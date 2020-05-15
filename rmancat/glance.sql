ALTER SESSION SET nls_date_format = 'yyyy-mm-dd hh24:mi'
SET linesize 160 pages 300

COLUMN input_type NEW_VALUE sp_inputtype NOPRINT
COLUMN start_time NEW_VALUE sp_starttime NOPRINT
COLUMN end_time NEW_VALUE sp_endtime  NOPRINT
COLUMN status NEW_VALUE sp-status NOPRINT
COLUMN errors FORMAT A160

TTITLE "Input: " sp_inputtype. "   Status: " sp_status SKIP -
  "Start Time: " sp_starttime "   End Time: " sp_endtime
  
BREAK ON input_type SKIP PAGE ON REPORT

SET verify OFF

SELECT input_type || CASE WHEN incremental_level IS NOT NULL THEN ' (' || incrmeental_level || ')' ELSE NULL END as input_type,
       start_time,
       end_time,
       status,
       LISTAGG(output, CHR(13) || (CHR(10) )
         WITHIN GROUP (ORDER BY stamp) AS errors
  FROM ( SELECT incremental_level,
                d1.input_type,
                d1.start_time,
                d1.end_time,
                d1.status,
                ro.stamp,
                ROW_NUMBER() OVER ( PARTITION BY ro.session_key,
                                                 ro.db_key
                                        ORDER BY ro.stamp ASC
                                  ) rnum_ro,
                ro.output AS output
           FROM ( SELECT *
                    FROM ( SELECT db_key,
                                  input_type,
                                  start_time,
                                  end_time,
                                  incremental_level,
                                  session_recid,
                                  session_key,
                                  session_stamp,
                                  FIRST_VALUE ( session_key IGNORE NULLS)
                                    OVER ( PARTITION BY input_type,
                                                        incremental_level
                                               ORDER BY end_time DESC NULLS LAST
                                         ) fval_sk,
                                  status 
                             FROM ( SELECT jdet.session_key,
                                           jdet.db_key,
                                           jdet.start_time,
                                           jdet.end_time,
                                           jdet.input_type,
                                           jdet.session_stamp,
                                           MAX(bp.incremental_level)
                                             OVER ( PARTITION BY  jdet.db_name,
                                                                  jdet.input_type,
                                                                  rs.session_key
                                                  ) incremental_level,
                                           jdet.status,
                                           ROW_NUMBER() OVER ( PARTITION BY jdet.db_name,
                                                                            jdet.input_type,
                                                                            rs.session_key
                                                                   ORDER BY CASE WHEN rs.status != 'COMPLETED'
                                                                                 THEN 1
                                                                                 ELSE 99
                                                                             END ASC,
                                                                             rs.stamp ASC
                                                             ) rnum
                                      FROM rc_rman_backup_job_details jdet
                                     INNER JOIN rc_rman_status rs ON 
                                         (     rs.session_recid = jdet.session_recid
                                           AND rs.session_stamp = jdet.session_stamp
                                           AND rs.session_key = jdet.session_key
                                           AND rs.row_level <= 1
                                         )
                                      LEFT OUTER JOIN rc_backup_piece bp ON
                                        (     bp.rsr_key = rs.rsr_key
                                          AND bp.db_key = jdet.db_key
                                          AND bp.piece# = 1
                                          AND bp.copy# = 1
                                        )
                                     WHERE jdet.end-time > SYSDATE - 60
                                       AND jdet.db_name = '&sp_database.'
                                       AND EXISTS ( SELECT NULL
                                                      FROM rc_rman_status rs1
                                                     WHERE rs1.session_key = rs.session_key
                                                       AND rs1.db_key = rs.db_key
                                                       AND rs1.operation = 'BACKUP'
                                                       AND rownum <= 1
                                                   )
                                  )
                            WHERE rnum = 1
                         ) A1
                   WHERE session_key = fval_sk
                )
           LEFT OUTER JOIN rc-rman_output ro ON
                      (   ro.session_key = d1.session_key
                        AND ro.db_key = d1.db_key
                        AND d1.status NOT IN ('COMPLETED','RUNNING')
                        AND regexp_like (ro.output,'(RMAN|ORA)\-')
                      )
       )
 WHERE rnum_ro <= 20
 GROUP BY incremental_level,
          input_type,
          start_time,
          end_time,
          status
 ORDER BY input_type;