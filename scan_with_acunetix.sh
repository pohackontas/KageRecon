#!/bin/bash
target=$1
parallel=/usr/local/bin/parallel
python=/usr/local/bin/python3.9

sudo rm -f $target/info/acunetix_status.done

ls $target/*/*.http | $parallel --jobs 5 $python acunetix.py -d slow -f http://{/.} -u {//}/URLs.txt -r {//}/acunetix_report.txt
ls $target/*/*.https | $parallel --jobs 5 $python acunetix.py -d slow -f https://{/.} -u {//}/URLs.txt -r {//}/acunetix_report.txt

sudo touch $target/info/acunetix_status.done
