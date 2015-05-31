#!/usr/bin/env python
"""Map gkp UID to ZMW id.
'@m000_000/3/90596_91636' FASTQ
  or
'>m000_000/3/90596_91636' FASTA
  can look like
'100000000004    4       m000_000/3/90596_91636'
  in gkpStore.fastqUIDmap, so we parse such a line and record the mapping,
  in this case:
4 => 3
"""
import re, sys

re_fastqUIDmap = re.compile(r'[0-9]+\s+([0-9]+)\s+([^/]+/[0-9]+/[\S]+)')

def line2pair(line):
    """
    >>> line2pair('100000000004    4       m000_000/3/90596_91636')
    ('4', 'm000_000/3/90596_91636')
    """
    mo = re_fastqUIDmap.search(line)
    return mo.groups()
def main():
    for line in sys.stdin:
        uid, zmw = line2pair(line)
        sys.stdout.write('%s %s\n' %(uid, zmw))
def test():
    import doctest
    doctest.testmod()
if __name__=="__main__":
    if len(sys.argv) > 1:
        test()
        sys.exit(0)
    main()
