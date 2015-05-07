#!/usr/bin/env python
from __future__ import division
import sys, os, random
from random import choice

DNA_BASES = ['A', 'C', 'G', 'T']
COMPLEMENT = {
    'A': 'T',
    'C': 'G',
    'G': 'C',
    'T': 'A',
}
complement = lambda x: (COMPLEMENT[base] for base in x)

def WriteSplit(write, seq, split=60):
    nfull = len(seq) // split
    for i in range(nfull):
        slice = seq[i*split:(i+1)*split]
        write(''.join(slice))
        write('\n')
    if nfull < len(seq):
        slice = seq[nfull*split:]
        write(''.join(slice))
        write('\n')
def synth(dna_len, ref_writer, writer):
    '''
    Writer FASTA files:
        ref_writer: reference (source DNA)
        writer: all "reads"
    '''
    class DnaCreator(object):
        def Create(self, n):
            return [choice(DNA_BASES) for _ in range(n)]
    class Loader(object):
        worst_len = 1
        best_len = 10
        def __init__(self, n_zmws):
            self.n_zmws = n_zmws
        def Load(self):
            worst_len = self.worst_len
            best_len = self.best_len
            n_zmws = self.n_zmws
            tlen = len(dna)
            for i in range(self.n_zmws):
                beg = random.randrange(len(dna))
                end = beg + random.randrange(worst_len, best_len + 1)
                end = min(end, tlen)
                yield (i, beg, end)
    class Ringer(object):
        def Ring(self, i, beg, end):
            capA = []
            capB = []
            ring = dna[beg:end] + capA + list(complement(reversed(dna[beg:end]))) + capB
            return ring
    class Reader(object):
        def Read(self, ring, n):
            '''No inserts or deletes yet.
            '''
            l = len(ring)
            curr = random.randrange(l)
            while n:
                yield ring[curr]
                curr += 1
                if curr == l:
                    curr = 0
                n -= 1
    dna = DnaCreator().Create(dna_len)
    ref_writer.write(">rand%d\n" %dna_len)
    WriteSplit(ref_writer.write, dna)
    n_zmws = 100
    loader = Loader(n_zmws)
    ringer = Ringer()
    reader = Reader()
    avg_read_len = 100
    total_read_len = 0
    for i, beg, end in loader.Load():
        writer.write(">m000_000/{0:d}/{1:d}_{2:d}\n".format(i, beg, end))
        #print dna[beg:end]
        ring = ringer.Ring(i, beg, end)
        #print ring
        n = random.randrange(avg_read_len * 2)
        read = reader.Read(ring, n)
        writer.write(''.join(read))
        writer.write('\n')
        total_read_len += n
    coverage = total_read_len / dna_len
    sys.stderr.write(repr(locals().keys()))
    sys.stderr.write("""
dna_len={dna_len}
n_zmws={n_zmws}
avg_read_len={avg_read_len}
total={total_read_len}
coverage={coverage:.1f}x
""".format(**locals()))
        
    #reader = PbReader(dna)
def main():
    with open('ref.fasta', 'w') as ref_writer, open('cx.fasta', 'w') as writer:
        synth(1000, ref_writer, writer)
if __name__ == "__main__":
    main()