import sys
from pbcore.io import FastaIO

reader = FastaIO.FastaReader(sys.argv[1])
writer = FastaIO.FastaWriter(sys.stdout)

for record in reader:
    seq_length = len(record.sequence) 
    zmw, bounds = record.header.split('/')
    start, end = [int(k) for k in bounds.split('_')]
    new_end = start + seq_length

    new_header = "m000_000/{zmw}/{start}_{end}".format(zmw=zmw, start=start, end=new_end)

    writer.writeRecord(new_header, record.sequence)
