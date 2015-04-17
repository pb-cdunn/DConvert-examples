CELERA_DIR=/home/UNIXHOME/mkinsella/builds/mainline_031615/analysis/bin/wgs-8.1/Linux-amd64/bin
DAZZ_DIR=/home/UNIXHOME/mkinsella/github_repos/DAZZ_DB
DALIGN_DIR=/home/UNIXHOME/mkinsella/github_repos/DALIGNER
DCONVERT_DIR=/home/UNIXHOME/mkinsella/github_repos/DConvert

DALIGNER_OPTS=-k25 -w5 -h60 -e.95 -s500 -M28 -t12

CORRECTED_FASTA=corrected.fasta
DAZZ_DBFILE=corrected.db
CORRECTED_FASTQ=corrected.fastq
CORRECTED_FRG=corrected.frg

MERGED_LAS=merged.las
TRIMMED_READS_PB=trimmed_reads.pb
MERGED_OVB=ovls.ovb

GKPSTORE=gkpstore
OVERLAPSTORE=overlapstore
FRG_CORR=frg_corr
OLAP_ERATES=olap_erates
TIGSTORE=tigstore
TIG_LIST=tigs.lst
DRAFT_ASSEMBLY=draft_assembly.fasta

# This gets the number of reads in the gkpstore
GKPFRAGS=$(CELERA_DIR)/gatekeeper -lastfragiid

all: $(DRAFT_ASSEMBLY)

$(DAZZ_DBFILE): $(CORRECTED_FASTA)
	$(DAZZ_DIR)/fasta2DB $@ $<
	$(DAZZ_DIR)/DBsplit -a $@

$(MERGED_LAS): $(DAZZ_DBFILE)
	$(DALIGN_DIR)/HPCdaligner $(DALIGNER_OPTS) $< > daligner_cmds.txt	
	mkdir -p dalign_cmds
	for i in $$(seq 1 `wc -l < daligner_cmds.txt`) ; do sed -n "$$i p" daligner_cmds.txt > dalign_cmds/dalign.$$i.sh ; done
	python ./run_dalign.py dalign_cmds
	$(DALIGN_DIR)/LAmerge $@ corrected.?.las corrected.??.las
	rm corrected.*.las

$(TRIMMED_READS_PB): $(MERGED_LAS) 
	$(DCONVERT_DIR)/read_from_las --las $< --db $(DAZZ_DBFILE) | $(DCONVERT_DIR)/trim_reads --min_spanned_coverage 1 --overlaps - > $@ 2> read_trimming.log
	$(DCONVERT_DIR)/read_from_las --las $< --db $(DAZZ_DBFILE) | $(DCONVERT_DIR)/trim_overlaps --overlaps - --trimmed_reads $@  2> overlap_trimming.log | $(DCONVERT_DIR)/write_to_ovb --style ovl > $(MERGED_OVB) 2> write_ovb.log

$(CORRECTED_FASTQ): $(CORRECTED_FASTA)
	python ./fake_fastq.py $< > $@

$(GKPSTORE): $(CORRECTED_FRG) $(CORRECTED_FASTQ) $(TRIMMED_READS_PB)
	$(CELERA_DIR)/gatekeeper -o $(GKPSTORE) -T -F $<
	$(DCONVERT_DIR)/apply_trimming_to_gkp --gkp $(GKPSTORE) --trimmed_reads $(TRIMMED_READS_PB)

$(OVERLAPSTORE): $(TRIMMED_READS_PB) $(GKPSTORE)
	ls $(MERGED_OVB) > ovl.list
	$(CELERA_DIR)/overlapStoreBuild -o $@.BUILDING -g $(GKPSTORE) -M 1021 -L ovl.list
	mv $@.BUILDING $@

$(FRG_CORR): | $(OVERLAPSTORE)
	python ./make_frg_correct.py `$(GKPFRAGS) $(GKPSTORE)` > $@_cmds.txt
	mkdir -p $@_dir
	for i in $$(seq 1 `wc -l < $@_cmds.txt`) ; do sed -n "$$i p" $@_cmds.txt > $@_dir/$@.$$i.sh ; done
	for i in $@_dir/*.sh ; do qsub -S /bin/bash -sync y -V -q production -N $@ -o $$PWD/$$i.log -e $$PWD/$$i.log -pe smp 3 $$i & sleep 1 ; done ; wait
	ls $@_dir/*.WORKING > $@.list
	$(CELERA_DIR)/cat-corrects -L $@.list -o $@

$(OLAP_ERATES): $(FRG_CORR)
	python ./make_olap_correct.py `$(GKPFRAGS) $(GKPSTORE)` > $@_cmds.txt
	mkdir -p $@_dir
	for i in $$(seq 1 `wc -l < $@_cmds.txt`) ; do sed -n "$$i p" $@_cmds.txt > $@_dir/$@.$$i.sh ; done
	for i in $@_dir/*.sh ; do qsub -S /bin/bash -sync y -V -q production -N $@ -o $$PWD/$$i.log -e $$PWD/$$i.log -pe smp 3 $$i & sleep 1 ; done ; wait
	ls $@_dir/*.WORKING > $@.list
	$(CELERA_DIR)/cat-erates -L $@.list -o $@

ovlstore_update: $(OLAP_ERATES)
	$(CELERA_DIR)/overlapStore -u $(OVERLAPSTORE) $(OLAP_ERATES)
	touch ovlstore_update

$(TIG_LIST): $(OVERLAPSTORE)
	mkdir -p bogart
	$(CELERA_DIR)/bogart -O $(OVERLAPSTORE) -G $(GKPSTORE) -T $(TIGSTORE) -D intersections -B 75000 -eg 0.04 -Eg 4.0 -em 0.045 -Em 5.25 -o bogart/bogart
	$(CELERA_DIR)/tigStore -g $(GKPSTORE) -t $(TIGSTORE) 1 -d properties -U | \
		awk 'BEGIN{t=0}$$1=="numFrags"{if($$2>1){print t, $$2}t++}' | sort -nrk2,2 > $@

$(DRAFT_ASSEMBLY): $(TIG_LIST)
	mkdir -p utgtmp
	tmp=$$PWD/utgtmp gkp=$$PWD/$(GKPSTORE) tig=$$PWD/$(TIGSTORE) utg=$$PWD/$(TIG_LIST) cns=$$PWD/$(DRAFT_ASSEMBLY) nproc=6 \
		tsadapt=$$PWD/tigStore-adapter.py ./pbutgcns_wf.sh

mummer: $(DRAFT_ASSEMBLY)
	~/MUMmer3.23/nucmer --maxgap=500 --mincluster=100 --prefix=ref_asm /lustre/hpcprod/jdrake/arab/test/eval/GCA_000835945.1_ASM83594v1_genomic.fna $<
	~/MUMmer3.23/show-coords -r ref_asm.delta -L 10000

.PHONY: clean

clean:
	rm -f $(CORRECTED_FASTA)
	rm -f $(DAZZ_DBFILE)
	rm -f .$(basename $(DAZZ_DBFILE))*
	rm -f $(basename $(DAZZ_DBFILE)).*.las
	rm -f obt_merged.las ovl_merged.las $(TRIMMED_READS_PB)
	rm -f $(MERGED_LAS) $(MERGED_OVB) ovl.list
	rm -rf $(GKPSTORE) $(OVERLAPSTORE) $(TIGSTORE) bogart
	rm -f gkpstore* $(TIG_LIST)
	rm -f $(OLAP_ERATES)* $(FRG_CORR)*
	rm -f best.*
	rm -f ovlstore_update
