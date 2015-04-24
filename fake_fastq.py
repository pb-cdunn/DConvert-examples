import sys

from pbcore.io import FastqIO, FastaIO

def main(fasta_name):

    reader = FastaIO.FastaReader(fasta_name)
    writer = FastqIO.FastqWriter(sys.stdout)

    for record in reader:
        writer.writeRecord(record.header, record.sequence, [20]*len(record.sequence))

if __name__ == '__main__':
    main(sys.argv[1])
