import os
import re
import string
import sys
MK = '/lustre/hpcprod/mkinsella/arab_test'

PWD = os.getcwd()
PROG = '/home/UNIXHOME/mkinsella/celera_assembler_replacement/wgs-8.1/Linux-amd64/bin/correct-olaps'
OVERLAPSTORE = os.path.join(PWD, 'overlapstore')
OLAP_ERATES_DIR = os.path.join(PWD, 'olap_erates_dir')
GKPSTORE = os.path.join(PWD, 'gkpstore')
FRG_CORR = os.path.join(PWD, 'frg_corr')
BLOCK_SIZE = 2500
START = 1
END = int(re.findall('\d+', ' '.join(sys.argv[1:]))[0])
cmd_template = ("{prog} "
                "-S {ostore} "
                "-e {oed}/olap_erates.int.{i}.WORKING "
                "{gkpstore} "
                "{frg_corr} {start} {end}")

for i in xrange(END/BLOCK_SIZE + 1):
    print cmd_template.format(
            i=string.zfill(i+1, 2),
            ostore=OVERLAPSTORE,
            oed=OLAP_ERATES_DIR,
            gkpstore=GKPSTORE,
            frg_corr=FRG_CORR,
            start=BLOCK_SIZE*i+1,
            end=min(BLOCK_SIZE*(i+1), END),
            prog=PROG)
