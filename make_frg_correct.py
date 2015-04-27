import os
import re
import string
import sys
MK = '/lustre/hpcprod/mkinsella/arab_test'

PWD = os.getcwd()
PROG = '/home/UNIXHOME/mkinsella/celera_assembler_replacement/wgs-8.1/Linux-amd64/bin/correct-frags'
OVERLAPSTORE = os.path.join(PWD, 'overlapstore')
FRG_CORR_DIR = os.path.join(PWD, 'frg_corr_dir')
GKPSTORE = os.path.join(PWD, 'gkpstore')
BLOCK_SIZE = 2500
START = 1
END = int(re.findall('\d+', ' '.join(sys.argv[1:]))[0])
cmd_template = ("{prog} "
                "-t 2 -S {ostore} "
                "-o {fcdir}/frg_corr.{i}.int.WORKING "
                "{gkpstore} {start} {end}")

for i in xrange(END/BLOCK_SIZE + 1):
    print cmd_template.format(
            i=string.zfill(i+1, 2),
            ostore=OVERLAPSTORE,
            fcdir=FRG_CORR_DIR,
            gkpstore=GKPSTORE,
            start=BLOCK_SIZE*i+1,
            end=min(BLOCK_SIZE*(i+1), END),
            prog=PROG)
