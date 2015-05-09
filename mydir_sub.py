import re, sys, os, fileinput

CWD = os.path.abspath(os.getcwd())

# For now, DALIGN hard-codes arab2_test.
re_dir = re.compile(r'\S*\barab2\w*\b')
def mydir(line, cwd):
    '''
    >>> mydir('x /abc/arab2_test/x', '/q')
    'x /q/x'
    >>> mydir('x /abc/arab2/x', '/q')
    'x /q/x'
    '''
    return re_dir.sub(cwd, line)
def test():
    import doctest
    doctest.testmod()
if __name__ == '__main__':
    if len(sys.argv) == 1:
        test()
        sys.exit()
    for line in fileinput.input(inplace=True, backup='.bak'):
        sys.stdout.write(mydir(line, CWD))
