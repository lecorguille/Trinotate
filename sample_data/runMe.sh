#!/bin/bash -e

SWISSPROT_SQLITE_DB_URL="http://sourceforge.net/projects/trinotate/files/TRINOTATE_RESOURCES/20140708/Trinotate.20140708.swissprot.sqlite.gz/download"

for file in *.gz
do
  if [ ! -e ${file%.gz} ]; then
      gunzip -c $file > ${file%.gz}
  fi
done

if [ ! -d edgeR_trans ]; then
    tar -zxvf edgeR_trans.tgz
fi

if [ ! -d edgeR_components ]; then
    tar -zxvf edgeR_components.tgz
fi

BOILERPLATE="Trinotate.boilerplate.sqlite"

if [ -e $BOILERPLATE ]; then
    echo $BOILERPLATE
    rm $BOILERPLATE
fi

if [ ! -s $BOILERPLATE.gz ]; then
    echo pulling swissprot resource db from SF ftp site
    wget $SWISSPROT_SQLITE_DB_URL -O $BOILERPLATE.gz
fi

gunzip -c $BOILERPLATE.gz > $BOILERPLATE


sqlite_db="myTrinotate.sqlite"

cp  $BOILERPLATE ${sqlite_db}

echo "###############################"
echo Loading protein set
echo "###############################"

../Trinotate ${sqlite_db} init --gene_trans_map Trinity.fasta.gene_trans_map --transcript_fasta Trinity.fasta --transdecoder_pep best_candidates.eclipsed_orfs_removed.pep



echo "##############################"
echo Loading blast results
echo "##############################"

../Trinotate ${sqlite_db} LOAD_swissprot_blastp swissprot.blastp.outfmt6
../Trinotate ${sqlite_db} LOAD_trembl_blastp uniref90.blastp.outfmt6


echo "#############################"
echo Loading PFAM results
echo "#############################"

../Trinotate ${sqlite_db} LOAD_pfam TrinotatePFAM.out


echo "############################"
echo Loading TMHMM results
echo "############################"

../Trinotate ${sqlite_db} LOAD_tmhmm tmhmm.out

echo "###########################"
echo Loading SignalP results
echo "###########################"

../Trinotate ${sqlite_db} LOAD_signalp signalp.out

echo "###########################"
echo Loading transcript BLASTX results
echo "###########################"

../Trinotate ${sqlite_db} LOAD_swissprot_blastx swissprot.blastx.outfmt6
../Trinotate ${sqlite_db} LOAD_trembl_blastx uniref90.blastx.outfmt6


echo "###########################"
echo Loading RNAMMER results
echo "###########################"

../Trinotate ${sqlite_db} LOAD_rnammer rnammer.gff


#################################################################
## Load Expression info and DE analysis results for Trinotate-web
#################################################################


# import the expression data (counts, fpkms, and samples)

echo "###################################"
echo Loading Component Expression Matrix
echo "###################################"

../util/transcript_expression/import_samples_n_expression_matrix.pl --sqlite ${sqlite_db} --component_mode --samples_file samples_n_reads_described.txt --count_matrix Trinity_components.counts.matrix --fpkm_matrix Trinity_components.counts.matrix.TMM_normalized.FPKM --bulk_load



echo "###################################"
echo Loading Transcript Expression Matrix
echo "###################################"

../util/transcript_expression/import_samples_n_expression_matrix.pl --sqlite ${sqlite_db} --transcript_mode --samples_file samples_n_reads_described.txt --count_matrix Trinity_trans.counts.matrix --fpkm_matrix Trinity_trans.counts.matrix.TMM_normalized.FPKM --bulk_load


# import the DE analysis results:

echo "###########################"
echo Loading DE results for transcripts
echo "###########################"

../util/transcript_expression/import_DE_results.pl --sqlite ${sqlite_db} --DE_dir edgeR_trans --transcript_mode --bulk_load

echo "###########################"
echo Loading DE results for components
echo "###########################"


../util/transcript_expression/import_DE_results.pl --sqlite ${sqlite_db} --DE_dir edgeR_components --component_mode --bulk_load

echo "######################################################"
echo Loading transcription profile clusters for transcripts
echo "######################################################"


# import the transcription profile cluster stuff
../util/transcript_expression/import_transcript_clusters.pl --group_name DE_all_vs_all --analysis_name edgeR_trans/diffExpr.P0.001_C2.matrix.R.all.RData.clusters_fixed_P_20 --sqlite ${sqlite_db} edgeR_trans/diffExpr.P0.001_C2.matrix.R.all.RData.clusters_fixed_P_20/*matrix


echo "###########################"
echo Generating report table
echo "###########################"

../Trinotate ${sqlite_db} report > Trinotate_report.xls

echo "#########################################"
echo Extracting Gene Ontology Mappings Per Gene
echo "#########################################"

../util/extract_GO_assignments_from_Trinotate_xls.pl  --Trinotate_xls Trinotate_report.xls -G -I > Trinotate_report.xls.gene_ontology

# Load annotations
../util/annotation_importer/import_transcript_names.pl ${sqlite_db} Trinotate_report.xls


echo "##########################"
echo done.  See annotation summary file:  Trinotate_report.xls
echo "##########################"
