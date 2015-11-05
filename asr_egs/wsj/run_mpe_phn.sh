#!/bin/bash

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.

. ./path.sh ## Source the tools/utils (import the queue.pl)

. utils/parse_options.sh || exit 1;

srcdir=exp/train_cv05_phn_l4_c320

acwt=0.9

learn_rate=0.00001
  # First we generate lattices and alignments:

#  steps/align.sh --nj 30 --cmd "$decode_cmd" \
#    data/lang_phn data/train_tr95 $srcdir ${srcdir}_ali || exit 1;

#  steps/make_denlats.sh --cmd "$decode_cmd" --nj 30 --beam 17.0 --lattice_beam 8.0 --max-active 5000 --acwt 0.9 \
#    data/lang_phn_test_tg data/train_tr95 $srcdir ${srcdir}_denlats || exit 1;


  # Re-train the DNN by 4 iteration of sMBR
  steps/train_mpe.sh --cmd "$cuda_cmd" --num-iters 4 --acwt $acwt --do-smbr true --learn-rate $learn_rate \
    data/train_tr95 data/lang_phn $srcdir ${srcdir}_ali ${srcdir}_denlats ${srcdir}_mpe_lr${learn_rate} || exit 1;
