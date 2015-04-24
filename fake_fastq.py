import sys
import sys, os
from pbcore.io import FastqIO, FastaIO

def main(fasta_name, ofile):
    reader = FastaIO.FastaReader(fasta_name)
    writer = FastqIO.FastqWriter(ofile)

    for record in reader:
        writer.writeRecord(record.header, record.sequence, [20]*len(record.sequence))

if __name__ == '__main__':
    iname, oname = sys.argv[1:3]
    ofile = open(oname, 'w')
    try:
        main(iname, ofile)
    except:
        # clean up (for make)
        ofile.close()
        os.unlink(oname)
        raise
