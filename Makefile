WML:=./wrap-module-load-exec.sh
MP:=/lustre/hpcprod/cdunn/modulefiles
MK:=mkinsella
MK:=cdunn
SMRT:=smrtanalysis/2.3.0.p2
SMRT:=smrtanalysis/2.3.0.nightly
SMRT:=smrtanalysis/mainline
CURRENT:=/mnt/secondary-siv/nightlytest/Ubuntu1404_Mainline_SGE_Install/smrtanalysis_148910/install/smrtanalysis_2.4.0.148910
SMRTWRAP:=../../mk/current/smrtcmds/bin/smrtwrap
#CELERA_DIR=/home/UNIXHOME/mkinsella/builds/mainline_031615/analysis/bin/wgs-8.1/Linux-amd64/bin
CELERA_DIR:=$(shell dirname $$(readlink -f $$(${WML} -m ${SMRT} which gatekeeper)))
DAZZ_DIR=/home/UNIXHOME/mkinsella/github_repos/DAZZ_DB
DAZZ_DIR=/lustre/hpcprod/cdunn/repo/gh/DAZZ_DB
DALIGN_DIR=/lustre/hpcprod/cdunn/repo/gh/DALIGNER
DCONVERT_DIR=/lustre/hpcprod/cdunn/repo/gh/DConvert

READ_FROM_LAS        :=${WML} -p ${MP} -m ${MK} ${DCONVERT_DIR}/read_from_las
TRIM_READS           :=${WML} -p ${MP} -m ${MK} ${DCONVERT_DIR}/trim_reads
TRIM_OVERLAPS        :=${WML} -p ${MP} -m ${MK} ${DCONVERT_DIR}/trim_overlaps
WRITE_TO_OVB         :=${WML} -p ${MP} -m ${MK} ${DCONVERT_DIR}/write_to_ovb
APPLY_TRIMMING_TO_GKP:=${WML} -p ${MP} -m ${MK} ${DCONVERT_DIR}/apply_trimming_to_gkp
GATEKEEPER           :=${CELERA_DIR}/gatekeeper
GATEKEEPER:=/lustre/hpcprod/cdunn/repo/gh/DConvert/celera_assembler/wgs-8.1/Linux-amd64/bin/gatekeeper

# This needs stuff for tigStore-adapter.py, which it calls.
PBUTGCNS_WF          :=${WML} -m ${SMRT} ./pbutgcns_wf.sh

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
GKPFRAGS=${GATEKEEPER} -lastfragiid

all: ${DRAFT_ASSEMBLY}

${DAZZ_DBFILE}: ${CORRECTED_FASTA}
	${DAZZ_DIR}/fasta2DB $@ $<
	${DAZZ_DIR}/DBsplit -a $@

#${MERGED_LAS}: ${DAZZ_DBFILE}
daligner_cmds.txt: ${DAZZ_DBFILE}
	${DALIGN_DIR}/HPCdaligner ${DALIGNER_OPTS} $< >| daligner_cmds.txt	
corrected.1.las: daligner_cmds.txt
	python mydir_sub.py daligner_cmds.txt
	mkdir -p dalign_cmds
	for i in $$(seq 1 `wc -l < daligner_cmds.txt`) ; do sed -n "$$i p" daligner_cmds.txt >| dalign_cmds/dalign.$$i.sh ; done
	PATH=${DALIGN_DIR}:$${PATH} python ./run_dalign.py dalign_cmds
${MERGED_LAS}: corrected.1.las
	${DALIGN_DIR}/LAmerge $@ corrected.?.las
	echo rm corrected.*.las

dazz-idx2zmw: ${DAZZ_DBFILE}
	${DAZZ_DIR}/DBshow -m ${DAZZ_DBFILE} >| dazz-idx2zmw

${TRIMMED_READS_PB}: ${MERGED_LAS} dazz-idx2zmw gkpstore.fastqUIDmap2zmw
	${READ_FROM_LAS} --las $< --db ${DAZZ_DBFILE} --out overlaps.pb
	${TRIM_READS} --min_spanned_coverage 1 --overlaps overlaps.pb --out $@ 2> trim_reads.log
	${TRIM_OVERLAPS} --overlaps overlaps.pb --trimmed_reads $@ --out trimmed_overlaps.pb 2> overlap_trimming.log 
	${WRITE_TO_OVB} --map-dazz dazz-idx2zmw --map-gkp gkpstore.fastqUIDmap2zmw --style ovl --overlaps trimmed_overlaps.pb --out ${MERGED_OVB} 2> write_ovb.log

${CORRECTED_FASTQ}: ${CORRECTED_FASTA}
	${WML} -m ${SMRT} python ./fake_fastq.py $< $@

gkpstore.fastqUIDmap2zmw: ${CORRECTED_FRG} ${CORRECTED_FASTQ}
	# This will *not* modify an existing gkpstore.
	${GATEKEEPER} -o ${GKPSTORE} -T -F ${CORRECTED_FRG}
	# IDs are slightly remapped.
	python mapGk2Zmz.py < gkpstore.fastqUIDmap >| gkpstore.fastqUIDmap2zmw

$(GKPSTORE).done: gkpstore.fastqUIDmap2zmw ${TRIMMED_READS_PB}
	${APPLY_TRIMMING_TO_GKP} --map-dazz dazz-idx2zmw --map-gkp gkpstore.fastqUIDmap2zmw --gkp $(GKPSTORE) --trimmed_reads ${TRIMMED_READS_PB}
	touch ${GKPSTORE}.done

$(OVERLAPSTORE): $(TRIMMED_READS_PB) ${GKPSTORE}.done
	ls $(MERGED_OVB) > ovl.list
	$(CELERA_DIR)/overlapStoreBuild -o $@.BUILDING -g $(GKPSTORE) -M 1021 -L ovl.list
	mv $@.BUILDING $@

$(FRG_CORR): | $(OVERLAPSTORE)
	python ./make_frg_correct.py `$(GKPFRAGS) $(GKPSTORE)` > $@_cmds.txt
	mkdir -p $@_dir
	for i in $$(seq 1 `wc -l < $@_cmds.txt`) ; do sed -n "$$i p" $@_cmds.txt > $@_dir/$@.$$i.sh ; done
	for i in $@_dir/*.sh ; do $$i ; done
	ls $@_dir/*.WORKING > $@.list
	$(CELERA_DIR)/cat-corrects -L $@.list -o $@

$(OLAP_ERATES): $(FRG_CORR)
	python ./make_olap_correct.py `$(GKPFRAGS) $(GKPSTORE)` > $@_cmds.txt
	mkdir -p $@_dir
	for i in $$(seq 1 `wc -l < $@_cmds.txt`) ; do sed -n "$$i p" $@_cmds.txt > $@_dir/$@.$$i.sh ; done
	for i in $@_dir/*.sh ; do $$i ; done
	ls $@_dir/*.WORKING > $@.list
	$(CELERA_DIR)/cat-erates -L $@.list -o $@

ovlstore_update: ${OLAP_ERATES}
	$(CELERA_DIR)/overlapStore -u ${OVERLAPSTORE} $<
	touch ovlstore_update

${TIG_LIST}: ${OVERLAPSTORE}
	mkdir -p bogart
	${CELERA_DIR}/bogart -O ${OVERLAPSTORE} -G ${GKPSTORE} -T ${TIGSTORE} -D intersections -B 75000 -eg 0.04 -Eg 4.0 -em 0.045 -Em 5.25 -o bogart/bogart
	${CELERA_DIR}/tigStore -g ${GKPSTORE} -t ${TIGSTORE} 1 -d properties -U | \
		awk 'BEGIN{t=0}$$1=="numFrags"{if($$2>1){print t, $$2}t++}' | sort -nrk2,2 > $@

${DRAFT_ASSEMBLY}: ${TIG_LIST}
	mkdir -p utgtmp
	tmp=$$PWD/utgtmp gkp=$$PWD/${GKPSTORE} tig=$$PWD/${TIGSTORE} utg=$$PWD/${TIG_LIST} cns=$$PWD/${DRAFT_ASSEMBLY} nproc=6 \
		tsadapt=$$PWD/tigStore-adapter.py ${PBUTGCNS_WF}

REF:=/lustre/hpcprod/jdrake/arab/test/eval/GCA_000835945.1_ASM83594v1_genomic.fna
REF:=/mnt/secondary-siv/references/ecoli_mutated/sequence/ecoli_mutated.fasta
mummer: ${DRAFT_ASSEMBLY}
	/home/${MK}/MUMmer3.23/nucmer --maxgap=500 --mincluster=100 --prefix=ref_asm ${REF} $<
	/home/${MK}/MUMmer3.23/show-coords -r ref_asm.delta -L 10000

corrected.fasta: cx.fasta
	${WML} -m ${SMRT} python ./relabel_fasta.py $< $@

ex.out: ${DRAFT_ASSEMBLY}
	${WML} -m exonerate/2.0.0 fastalength $< > $@
fastalength: #${DRAFT_ASSEMBLY}
	${WML} -m exonerate/2.0.0 fastalength ${DRAFT_ASSEMBLY}
out.report: ${DRAFT_ASSEMBLY}
	${WML} -m mummer/3.23 dnadiff ${REF} $<
foo:
	${WML} -m mummer/3.23 which dnadiff
check:
	python check.py from.fasta cx.fasta
# See *.report

.PHONY: clean

clean:
	rm -f ${CORRECTED_FASTA}
	rm -f ${DAZZ_DBFILE}
	rm -f .${basename ${DAZZ_DBFILE}}*
	rm -f ${basename ${DAZZ_DBFILE}}.*.las
	rm -f obt_merged.las ovl_merged.las ${TRIMMED_READS_PB}
	rm -f ${MERGED_LAS} ${MERGED_OVB} ovl.list
	rm -rf ${GKPSTORE} ${OVERLAPSTORE} ${TIGSTORE} bogart
	rm -f gkpstore* ${TIG_LIST}
	rm -f ${OLAP_ERATES}* ${FRG_CORR}*
	rm -f best.*
	rm -f ovlstore_update
	rm -rf daligner_cmds.txt dalign_cmds/
	rm -f *.log
