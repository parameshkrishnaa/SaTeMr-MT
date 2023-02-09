#!/bin/sh
#
##  Copyright (C) 2002-2022 Amba Kulkarni (ambapradeep@gmail.com)
##
##  This program is free software; you can redistribute it and/or
##  modify it under the terms of the GNU General Public License
##  as published by the Free Software Foundation; either
##  version 2 of the License, or (at your option) any later
##  version.
##
##  This program is distributed in the hope that it will be useful,
##  but WITHOUT ANY WARRANTY; without even the implied warranty of
##  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##  GNU General Public License for more details.
##
##  You should have received a copy of the GNU General Public License
##  along with this program; if not, write to the Free Software
##  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#


   SCLINSTALLDIR=$1
   GraphvizDot=$2
   TMP_FILES_PATH=$3
   OUTSCRIPT=$6
   PARSE=$7
   TEXT_TYPE=$8

   ANU_MT_PATH=$SCLINSTALLDIR/MT/prog
   mkdir -p $TMP_FILES_PATH/parser_files

   if [ $PARSE != "NO" ] ; then
 
      $ANU_MT_PATH/kAraka/uniform_morph_anal.pl $SCLINSTALLDIR $TMP_FILES_PATH <  $TMP_FILES_PATH/$4
      $ANU_MT_PATH/kAraka/split_multisentence_input.pl $TMP_FILES_PATH/parser_files/morph < $TMP_FILES_PATH/$4
 
      $ANU_MT_PATH/kAraka/Prepare_Graph/build_graph $TMP_FILES_PATH/parser_files/ $TEXT_TYPE < $TMP_FILES_PATH/parser_files/1.clp  |\
      $ANU_MT_PATH/kAraka/kaaraka_sharing.pl $SCLINSTALLDIR $ANU_MT_PATH/kAraka/Prepare_Graph/DATA/AkAfkRA/relations.txt > $TMP_FILES_PATH/parser_files/parseop1.txt

      $ANU_MT_PATH/kAraka/add_parser_output.pl $SCLINSTALLDIR $ANU_MT_PATH/kAraka/Prepare_Graph/DATA/AkAfkRA/relations.txt $TMP_FILES_PATH/parser_files/parseop1.txt 1 < $TMP_FILES_PATH/parser_files/morph1.out |\
      $ANU_MT_PATH/kAraka/add_abhihita_info.pl > $TMP_FILES_PATH/parser_files/morph1_1.out
      $ANU_MT_PATH/kAraka/prepare_dot_files.sh $SCLINSTALLDIR $GraphvizDot $OUTSCRIPT 1 mk_kAraka_help.pl $TMP_FILES_PATH/parser_files/morph1.out $TMP_FILES_PATH/parser_files/parseop1.txt $TMP_FILES_PATH 1
      cat $TMP_FILES_PATH/parser_files/morph1_1.out >> $TMP_FILES_PATH/$4.1
      mv $TMP_FILES_PATH/$4.1 $TMP_FILES_PATH/$4
 
  else

     touch $TMP_FILES_PATH/parser_files/parseop.txt
     $ANU_MT_PATH/kAraka/handle_no_parse.pl < $TMP_FILES_PATH/$4 |\
     $ANU_MT_PATH/kAraka/add_parser_output.pl $ANU_MT_PATH/kAraka/Prepare_Graph/DATA/AkAfkRA/relations.txt $TMP_FILES_PATH/parser_files/parseop.txt 1 $GH_INPUT > $TMP_FILES_PATH/$4

  fi
