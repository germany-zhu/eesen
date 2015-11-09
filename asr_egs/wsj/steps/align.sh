#!/bin/bash

# Apache 2.0

# Decode the CTC-trained model by generating lattices.   


## Begin configuration section
stage=0
nj=16
cmd=run.pl
num_threads=1

scale_opts="--transition-scale=1.0 --acoustic-scale=0.9 --self-loop-scale=0.1"
retry_beam=40

#acwt=0.9
#min_active=200
#max_active=7000 # max-active
beam=15.0       # beam used
#lattice_beam=8.0
#max_mem=50000000 # approx. limit to memory consumption during minimization in bytes

#skip_scoring=true # whether to skip WER scoring
#scoring_opts="--min-acwt 5 --max-acwt 10 --acwt-factor 0.1"

# feature configurations; will be read from the training dir if not provided
norm_vars=
add_deltas=
## End configuration section

echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh;
. parse_options.sh || exit 1;

if [ $# != 4 ]; then
   echo "Wrong #arguments ($#, expected 3)"
   echo "Usage: steps/decode_ctc.sh [options] <lang-dir> <data-dir> <src-dir> <exp-dir>"
   echo " e.g.: steps/decode_ctc.sh data/lang data/test exp/train_l4_c320/decode"
   echo "main options (for others, see top of script file)"
   echo "  --stage                                  # starts from which stage"
   echo "  --nj <nj>                                # number of parallel jobs"
   echo "  --cmd <cmd>                              # command to run in parallel with"
   echo "  --acwt                                   # default 0.9, the acoustic scale to be used"
   exit 1;
fi

langdir=$1
data=$2
srcdir=$3
dir=$4


sdata=$data/split$nj;

thread_string=
[ $num_threads -gt 1 ] && thread_string="-parallel --num-threads=$num_threads"

[ -z "$add_deltas" ] && add_deltas=`cat $srcdir/add_deltas 2>/dev/null`
[ -z "$norm_vars" ] && norm_vars=`cat $srcdir/norm_vars 2>/dev/null`

mkdir -p $dir/log
split_data.sh $data $nj || exit 1;
echo $nj > $dir/num_jobs

# Check if necessary files exist.
for f in $langdir/oov.int $langdir/T.fst $langdir/L.fst $srcdir/label.counts $data/feats.scp; do
  [ ! -f $f ] && echo "$0: no such file $f" && exit 1;
done

oov=`cat $langdir/oov.int`;

## Set up the features
echo "$0: feature: norm_vars(${norm_vars}) add_deltas(${add_deltas})"
#feats="ark,c,cs:copy-feats scp:$sdata/JOB/feats.scp ark:- |"
#
#feats="$feats apply-cmvn --norm-vars=$norm_vars --utt2spk=ark:$sdata/JOB/utt2spk scp:$sdata/JOB/cmvn.scp ark:- ark:- |"
#$add_deltas && feats="$feats add-deltas ark:- ark:- |"
feats="ark,s,cs:apply-cmvn --norm-vars=$norm_vars --utt2spk=ark:$sdata/JOB/utt2spk scp:$sdata/JOB/cmvn.scp scp:$sdata/JOB/feats.scp ark:- |"
$add_deltas && feats="$feats add-deltas ark:- ark:- |"

feats="$feats nnet-forward --class-frame-counts=$srcdir/label.counts --apply-log=true --no-softmax=false $srcdir/final.nnet ark:- ark:- |"
##
#tra="ark:utils/sym2int.pl --map-oov $oov -f 2- $lang/words.txt $sdata/JOB/text|";
tra="ark:utils/sym2int.pl --map-oov $oov -f 2- $langdir/words.txt $sdata/JOB/text |";

#tra="$tra compile-train-graphs-end-end $langdir/T.fst $langdir/L.fst ark:- ark:- |"
#  $cmd JOB=1:$nj $dir/log/align.JOB.log \
#    align-compiled-mapped-end-end $scale_opts --beam=$beam --retry-beam=$retry_beam "$tra" \
#      "$feats" "ark,t:|gzip -c >$dir/ali.JOB.gz" || exit 1;

  $cmd JOB=1:$nj $dir/log/align.JOB.log \
    compile-train-graphs-end-end $langdir/T.fst $langdir/L.fst "$tra" ark:- \| \
    align-compiled-mapped-end-end $scale_opts --beam=$beam --retry-beam=$retry_beam ark:- \
      "$feats" "ark,t:|gzip -c >$dir/ali.JOB.gz" || exit 1;

# Decode for each of the acoustic scales
#$cmd JOB=1:$nj $dir/log/decode.JOB.log \
#  nnet-forward --class-frame-counts=$srcdir/label.counts --apply-log=true --no-softmax=false $srcdir/final.nnet "$feats" ark:- \| \
#  latgen-faster  --max-active=$max_active --max-mem=$max_mem --beam=$beam --lattice-beam=$lattice_beam \
#  --acoustic-scale=$acwt --allow-partial=true --word-symbol-table=$graphdir/words.txt \
#  $graphdir/TLG.fst ark:- "scp:$dir/lat.store_separately_as_gz.scp" || exit 1;

#2) Generate 'scp' for reading the lattices

# Scoring
#if ! $skip_scoring ; then
#  if [ -f $data/stm ]; then # use sclite scoring.
#    [ ! -x local/score_sclite.sh ] && echo "Not scoring because local/score_sclite.sh does not exist or not executable." && exit 1;
#    local/score_sclite.sh $scoring_opts --cmd "$cmd" $data $graphdir $dir || exit 1;
#  else
#    [ ! -x local/score.sh ] && echo "Not scoring because local/score.sh does not exist or not executable." && exit 1;
#    local/score.sh $scoring_opts --cmd "$cmd" $data $graphdir $dir || exit 1;
#  fi
#fi

exit 0;
