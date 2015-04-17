Based on `/lustre/hpcprod/mkinsella/arab_test/`

# Files
## cx.fasta
`>200007/0_16442`
DALIGN expects a different format.
`>0/1/a_b`
where `b-a` is the number of base pairs. See `relabel_fast.py`.

## tigStoreAdapter.py
modified version from some other build

## pbutgcns_wf.sh
another modifed script from build
- Calls unitig-consensus
- Looks at overlaps and picks most common base at each common spot.

## correct.frg
- tells location of input file

## DCONVERT
Converts from various overlap formats.
Also contains the code to trim reads and overlaps, based on the pattern of overlaps that it sees.
  *  https://github.com/mckinsel/DConvert

# Basic flow
## daligner
- Jim -> cx.fasta (malformed for daligner)
  relabel_fasta -> corrected.fasta
  fasta2DB -> corrected.db (a dazzler DB file)
  daligner (with HPCdaligner (in DALIGN repo?) + run_dalign.py) -> merged.las (happens to be sorted; comes from a bunch of intermed. files)
    [DALIGN is VERY TIME-CONSUMING!]
  trimming (DCONVERT/PB) -> trimmed_reads.pb (protobuf haha!; kinda internal to trimming) + merged.ovb (for Celera)
(Note: HPCdaligner.c should be modifed not to write to CWD, maybe, says Marcus. It writes to paths that
 might not work well for dist. jobs.)
-> merged.ovb
  overlap_store (CA) -> overlapStore

-> corrected.fasta, corrected.frg (which came from a previous run of Celera perl)
  fake_fastq.py -> corrected.fastq
  gatekeeper (CA) (plus corrected.frg again) -> gkpstore (dir of binary-encoded reads; see also next section)
Note: Celera tends to store everything as bitfields, dependent on compiler flags.
Note: Celera likes to modify in-place.

-> trimmed_reads.pb
  apply_trimming_to_gkp -> gkpstore (modifies existing version)

-> overlapStore + gkpStore
  bogart (CA) -> tigStore (unitigs, but basically contigs)
  pbutgcns (PB) (maybe plus gkpStore) -> draft_assembly.fasta

# alt path
- frg
- olap_erates


# Dependencies
## Python
### Old way
SEYMOUR_HOME=/mnt/secondary-siv/nightlytest/siv4/smrtanalysis/current/
source $SH/etc/setup.sh
(See ready.sh)
That is bad in a shell b/c it screws LD_LIBRARY_PATH.

### New way
smrt bash script
### Another way?
GNU module
`module add smrt-analysis` or something like that.


# Other notes
`/mnt/secondary-siv/testdata` has some stuff,  but not for this project.

## FASTQ
```
@header
  SEQUENCE
+
  QUALITY (PHRED encoded; same length as sequence)
```

## corrected reads -> contigs
Old:
1. kmer counting
2. overlap
3. chimera detection
4. overlap
5. correction
6. layout/unitigging (bogart)
7. consensus (pbutgcns)

New:
1. daligner to overlap
2. chimera trimming
3a. correction?
3b. bogart
4. pbutgcns

Steps:
- PreAssembly (pbdagcon)
  - Input: raw reads
  - Output: corrected reads
  - Obj: Reduce error rate from 15% to 6%
- Assembly (Celera Assembler)
  - Input: corrected reads
  - Output: draft assembly
  - Obj: recreate the genome from which the reads were sampled
- Polishing
  - Input: Raw reads; Draft assembly
  - Output: Polished assembly

