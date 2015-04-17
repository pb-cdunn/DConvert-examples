import functools
import multiprocessing.dummy
import os
import subprocess
import sys
import time

QSUB_TEMPLATE = ("qsub -S /bin/bash -sync y -V -q production -N dalign.{i} -o $PWD/dalign_cmds/{log} "
                 "-e $PWD/dalign_cmds/{log} -pe smp {nproc} "
                 "-wd $PWD dalign_cmds/{sh}")
def qsub_run(cmd_file, nproc):
    base_cmd = os.path.basename(cmd_file)
    cmd_i = base_cmd.split('.')[1]
    cmd_log = base_cmd.replace(".sh", ".log")
    
    proc = subprocess.Popen(QSUB_TEMPLATE.format(sh=base_cmd, i=cmd_i,
                                                 log=cmd_log, nproc=nproc), shell=True)
    proc.communicate()

    if(proc.returncode != 0):
        time.sleep(10)
        proc = subprocess.Popen(QSUB_TEMPLATE.format(sh=base_cmd, i=cmd_i,
                                                     log=cmd_log, nproc=nproc), shell=True)
        proc.communicate()


def main(cmd_dir):
    cmd_shs = [os.path.join(cmd_dir, k) for k in os.listdir(cmd_dir)]
    cmd_shs.sort(key=lambda x: int(x.split('.')[-2]))
    
    daligner_cmd_shs = [k for k in cmd_shs if 'daligner' in file(k).read()]
    lamerge_sort_cmd_shs = [k for k in cmd_shs if 'LA' in file(k).read()]
    
    pool = multiprocessing.dummy.Pool(24)

    pool.map(functools.partial(qsub_run, nproc=8), daligner_cmd_shs, 1)
    pool.map(functools.partial(qsub_run, nproc=2), lamerge_sort_cmd_shs, 1)

if __name__ == '__main__':
    main(sys.argv[1])
