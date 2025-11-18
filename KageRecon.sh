#!/bin/bash
set -x # debug feature

target=$1
iplist=$2
blacklist=$3
addsubslist=$4

path=/data/$target
subfinderDir=/root/go/bin/subfinder
npoDir=/tools/nmap-parse-output/nmap-parse-output
httpx=/root/go/bin/httpx
dirsearch=/usr/local/bin/dirsearch
gospider=/root/go/bin/gospider
parallel=/usr/bin/parallel
aquatone=/tools/aquatone/aquatone -chrome-path /usr/bin/chromium-browser
nuclei=/root/go/bin/nuclei

masscanParam="-p 1-65535 --rate 3000 --wait 0 --open"
nmapParam="-sVC --open -v -n -T2"
dirsearchParam="-r -q --format=simple --exclude-sizes=0B  -t 2  --max-recursion-depth=4 -x 403,404,302,301,400"
gospiderParam="-d 4 --other-source --include-other-source -q"

# root check
if [[ $(id -u) != 0 ]]; then
    echo -e "\n[!] this operation requires root privileges"
    exit 0
fi

function deleteOutScoped(){
	if [ -s "$1" ]; then
		cat $1 | while read outscoped
		do
			if grep -q "^[*]" <<< $outscoped
			then
				outscoped="${outscoped:1}"
				sed -i /"$outscoped$"/d $2
			else
				sed -i /$outscoped/d $2
			fi
		done
	fi
}


function dedup_pics {
        max_files=$1
        dir_path=$2
        folder=1
        files=0

        # dedup all folder pics
        if [[ "$max_files" == 0 ]]; then
                echo "# Deduplication has started for " $dir_path
                python3 pic_dedup.py -p "$dir_path/"
        else
                for filename in $dir_path/*.png; do
                        # create folder for all manipulations
                        if [[ ! -d "$dir_path/temp/" ]] ;then mkdir $dir_path/temp/ ; fi

                        # create a new subfolder if it doesn't exist
                        if [[ ! -d "$dir_path/temp/$folder" ]] ;then mkdir $dir_path/temp/$folder ; fi

                        # mv and enumerate $max_files files
                        mv $filename $dir_path/temp/$folder
                        files=$((files+1))

                        # dedup the current subfolder and move on to the next one
                        if [[ "$files" == "$max_files" ]]; then
                                echo "# Deduplication has started for " $dir_path/temp/$folder
                                python3 pic_dedup.py -p "$dir_path/temp/$folder"
                                folder=$((folder+1))
                                files=0
                        fi
                done
                # dedup the last one
                echo "# Deduplication has started for " $dir_path/temp/$folder
                python3 pic_dedup.py -p "$dir_path/temp/$folder"

                # combine all folders into one
                find $dir_path/temp/*/ -type f -exec mv {} $dir_path \;
                # delete temp folder with empty subfolders
                rm -rf $dir_path/temp/
        fi
}

if [ -z "$target" ]; then
    echo -e "\n[!] Please specify the target"
    exit 0
fi

# washing files
sed -i -e 's/\r$//' $2
sed -i -e 's/\r$//' $3
sed -i -e 's/\r$//' $4

# never asked for this
if [ -z "$iplist" ];then
	rm -f empty_iplist.txt
	touch empty_iplist.txt
	iplist=empty_iplist.txt
fi

if [ -z "$blacklist" ];then
	rm -f empty_blacklist.txt
	touch empty_blacklist.txt
	blacklist=empty_blacklist.txt
fi

if [ -z "$addsubslist" ];then
	rm -f empty_addsubslist.txt
	touch empty_addsubslist.txt
	addsubslist=empty_addsubslist.txt
fi

python3 express_text.py -t "Scanning of the #${target} has started"
# $(date +"%H:%M %d.%m.%Y")

if [ ! -d "$path" ];then
	mkdir $path
fi

if [ ! -d "$path/info" ];then
	mkdir $path/info
fi

if [ -f "$path/info/newSubdomains.txt" ];then
	rm -f $path/info/newSubdomains.txt
fi

#todo - add import from input list

echo "Update FQDNs list"
touch $path/info/newSubdomains.txt

$subfinderDir -d $target -o $path/info/newSubdomains.txt | wc

sort -u $path/info/newSubdomains.txt -o $path/info/newSubdomains.txt
[ -s "$blacklist" ] && deleteOutScoped $blacklist $path/info/newSubdomains.txt 

if [ ! -f "$path/info/subdomains.txt" ];then
	touch $path/info/subdomains.txt
	else
		sort -u $path/info/subdomains.txt -o $path/info/subdomains.txt
fi

if [ ! -s "$path/info/subdomains.txt" ];then
	cat $path/info/newSubdomains.txt > $path/info/subdomains.txt
fi

#[ -s "$blacklist" ] && deleteOutScoped $blacklist $addsubslist

sort -u $addsubslist -o $addsubslist
cat $path/info/newSubdomains.txt $addsubslist | tee $path/info/newSubdomains.temp
sort -u $path/info/newSubdomains.temp -o $path/info/newSubdomains.temp
rm -f $path/info/newSubdomains.txt
cp $path/info/newSubdomains.temp $path/info/newSubdomains.txt 
rm -f $path/info/newSubdomains.temp


#todo - add rm -rf for blacklisted subdomains folders
[ -s "$blacklist" ] && deleteOutScoped $blacklist $path/info/newSubdomains.txt 
[ -s "$blacklist" ] && deleteOutScoped $blacklist $path/info/subdomains.txt

rm -f subdomains_with_IP.tmp
rm -f all_allowed_IP.tmp
rm -f outOfRangeFQDN_IP.txt

while read fqdn; do
        ip=$(ping -c1 -n $fqdn | head -n1 | sed "s/.*(\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\)).*/\1/g")
        if [[ ! -z "${ip}" ]]; then
                echo -e $fqdn' \t '$ip >> subdomains_with_IP.tmp
fi

done < $path/info/newSubdomains.txt

xargs -a $iplist -I % sh -c './cidr.sh % >> all_allowed_IP.tmp'

#добавить проверку что он существует
grep -vf all_allowed_IP.tmp subdomains_with_IP.tmp > outOfRangeFQDN_IP.txt

# uncomment this later. blacklist for IP
# [ -s "$blacklist" ] && deleteOutScoped $blacklist outOfRangeFQDN_IP.txt

cat outOfRangeFQDN_IP.txt | cut -f 1 > outOfRangeFQDN.txt

# проверяем что среди новых поддоменов нет не входящих в список IP
[ -s "$iplist" ] && deleteOutScoped outOfRangeFQDN.txt $path/info/newSubdomains.txt
[ -s "$iplist" ] && deleteOutScoped outOfRangeFQDN.txt $path/info/subdomains.txt

echo >> outOfRangeFQDN.txt
echo "#blacklist2 #${target}" >> outOfRangeFQDN.txt
[ -s "outOfRangeFQDN.txt" ] && python3 express_file.py --f "outOfRangeFQDN.txt"

rm -f $path/info/diffSubdomains.txt
touch $path/info/diffSubdomains.txt

sort -u $path/info/subdomains.txt -o $path/info/subdomains.txt
sort -u $path/info/newSubdomains.txt -o $path/info/newSubdomains.txt
comm -23 $path/info/newSubdomains.txt $path/info/subdomains.txt > $path/info/diffSubdomains.txt

[ -s "$blacklist" ] && deleteOutScoped $blacklist $path/info/diffSubdomains.txt

if [ -s "$path/info/diffSubdomains.txt" ];then
	echo "Found new subdomains!"
	cat $path/info/diffSubdomains.txt
	cat $path/info/diffSubdomains.txt >> $path/info/subdomains.txt
	sort -u $path/info/subdomains.txt -o $path/info/subdomains.txt
	cat $path/info/subdomains.txt
	echo >> $path/info/diffSubdomains.txt
	echo "#subdomains #${target}" >> $path/info/diffSubdomains.txt
	python3 express_file.py --f "$path/info/diffSubdomains.txt"

	else
	echo "New subdomains not found :^("
fi


if [ -f "$path/info/masscan.xml" ];then
	rm -f $path/info/masscan.xml
fi

# может отказаться от uniq ?
masscan $masscanParam -iL $iplist -oX $path/info/masscan.xml
open_ports=$(cat $path/info/masscan.xml | grep portid | cut -d "\"" -f 10 | sort -n | uniq | paste -sd,)
cat $path/info/masscan.xml | grep portid | cut -d "\"" -f 4 | sort -V | uniq > $path/info/nmap_targets.tmp
nmap $nmapParam -p $open_ports -iL $path/info/nmap_targets.tmp -oX $path/info/nmap.xml
rm -f $path/info/nmap_targets.tmp
$npoDir $path/info/nmap.xml host-ports > $path/info/ip_port.txt


rm -f $path/info/subdomains_port.txt
touch $path/info/subdomains_port.txt

#get ip from FQDN
n=1
while read fqdn; do
	IPofFQDN=$(ping -c1 -n $fqdn | head -n1 | sed "s/.*(\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\)).*/\1/g")

	#get ports of ip
	touch $path/info/OpenPort.txt
	#nmap -vv -p $open_ports $IPofFQDN | awk -F'[ /]' '/Discovered open port/{print $4}' > $path/info/OpenPort.txt
	masscan $IPofFQDN $masscanParam | awk -F'[ /]' '/Discovered open port/{print $4}' > $path/info/OpenPort.txt
	unset IPofFQDN

	#get FQDN:port
	if [ -s "$path/info/OpenPort.txt" ];then
			j=1
			while read port; do
			echo -e $fqdn | sed 's/$/:'$port'/' >> $path/info/subdomains_port.txt
			j=$((j+1))
			done < $path/info/OpenPort.txt
	else
			echo -e $fqdn >> $path/info/subdomains_port.txt
	fi

	rm -f $path/info/OpenPort.txt

	n=$((n+1))
done < $path/info/subdomains.txt


#todo - add new address discovery   
#cat $path/info/subdomains.txt $path/info/ip_port.txt > $path/info/OLD-subdmsAndIP.txt
cat $path/info/subdomains_port.txt $path/info/ip_port.txt > $path/info/subdmsAndIP.txt

[ -s "$blacklist" ] && deleteOutScoped $blacklist $path/info/subdmsAndIP.txt

targetsNumber=$(awk 'END { print NR }' $addsubslist $iplist)
totalTargetsNumber=$(awk 'END { print NR }' $path/info/subdmsAndIP.txt)
python3 express_text.py -t "#${target} Input targets: ${targetsNumber}. The total number of targets: ${totalTargetsNumber}"

#creation of a database
for address in $(cat $path/info/subdmsAndIP.txt)
do
	if [ ! -d "$path/$address" ];then
	mkdir $path/$address
	echo "Directory created - $path/$address"
	fi
done


#ls -d1 $path/* | $parallel --dry-run --jobs 5 "echo {/} | $httpx -silent > {}/httpx.result"
ls -d1 $path/* | $parallel --jobs 5 "echo {/} | $httpx -silent > {}/httpx.result"

rm -f $path/info/new_services.txt 
touch $path/info/new_services.txt

for address in $(cat $path/info/subdmsAndIP.txt)
do
	if [ -s $path/$address/httpx.result ];then
		echo "$address is a web-site"
		#proto= cat $path/$address/httpx.result | cut -d/ -f1 | sed 's/://' | tr -d '\n'
		#hostport= cat $path/$address/httpx.result | cut -d/ -f3 | tr -d '\n'
		proto="$( cat $path/$address/httpx.result | grep :// | sed -e's,^\(.*://\).*,\1,g')" 
		url=$( cat $path/$address/httpx.result | sed -e s,$proto,,g)
		hostport=$(echo $url | cut -d/ -f1)
		proto=$(echo $proto | sed 's/:\/\///')

		if [ ! -f "$path/$address/$hostport.$proto" ];then
			echo "$hostport.$proto" >> $path/info/new_services.txt
		fi
		touch $path/$address/$hostport.$proto
		else
		rm -f $path/$address/httpx.result
		rm -f $path/$address/*.https
		rm -f $path/$address/*.http
	fi
done


echo "NPO test"
rm -rf $path/info/groups
mkdir $path/info/groups
$npoDir $path/info/nmap.xml service-names | xargs -I % sh -c "$npoDir $path/info/nmap.xml service % > $path/info/groups/%"
#add tools to this point


for group in $(ls $path/info/groups/)
do
	for IP in $(cat $path/info/groups/$group)
	do
		echo $group
		if [ $group != 'http' ] && [ $group != 'https' ]; then
			
  	   		if [ -d $path/$IP ]; then
				if [ ! -f "$path/$IP/$IP.$group" ];then
        			echo "$IP.$group" >> $path/info/new_services.txt
             	   	touch $path/$IP/$IP.$group
				fi
      		else
				echo "$IP.$group" >> $path/info/new_services.txt
				echo "Error creating $path/$IP/$IP.$group" >> $path/info/create_group.log
				python3 express_text.py -t "Some errors in $path/info/create_group.log"
			fi
		#else
		#	echo "$IP.$group" >> $path/info/new_services.txt
		fi
	done
done

echo >> $path/info/new_services.txt
echo "#services #${target}" >> $path/info/new_services.txt
python3 express_file.py --f "$path/info/new_services.txt"

echo "test NPO"
cat $path/info/new_services.txt

#if [ -f $path/info/groups/ssh ]; then
#cp -ap $path/info/groups/ssh $path/info/SSH_alert.txt
#fi

echo "dirsearch started"
ls $path/*/*.https | $parallel --jobs 4 --timeout 10h "if [ ! -f {//}/_dirsearch_https_{/.} ] ; then echo {/.}; $dirsearch -u https://{/.} $dirsearchParam -o {//}/_dirsearch_https_{/.} | sed \"s/'//\" ; fi"
ls $path/*/*.http | $parallel --jobs 4 --timeout 10h "if [ ! -f {//}/_dirsearch_http_{/.} ] ; then echo {/.}; $dirsearch -u http://{/.} $dirsearchParam -o {//}/_dirsearch_http_{/.} | sed \"s/'//\" ; fi"

echo "gospider started"
ls $path/*/*.https | $parallel --jobs 2 --timeout 5h "if [ ! -f {//}/_gospider_https_{/.} ] ; then $gospider -s https://{/.} $gospiderParam | grep {/.} | cut -d ' ' -f5 > {//}/_gospider_https_{/.} | sed \"s/'//\"; fi"
ls $path/*/*.http | $parallel --jobs 2 --timeout 5h "if [ ! -f {//}/_gospider_http_{/.} ] ; then $gospider -s http://{/.} $gospiderParam | grep {/.} | cut -d ' ' -f5 > {//}/_gospider_http_{/.} | sed \"s/'//\"; fi"


for address in $(cat $path/info/subdmsAndIP.txt)
do
	if [ -s $path/$address/httpx.result ];then

		touch $path/$address/newURLs.txt
		cat $path/$address/_* >> $path/$address/newURLs.txt || echo error
		sort -u $path/$address/newURLs.txt -o $path/$address/newURLs.txt
		if [ ! -s $path/$address/newURLs.txt ];then
			touch $path/$address/noWebPages.status
		else
			rm -f $path/$address/noWebPages.status
		fi
		

		if [ ! -f "$path/$address/URLs.txt" ];then
			touch $path/$address/URLs.txt
			else
				sort -u $path/$address/URLs.txt -o $path/$address/URLs.txt
		fi

		if [ -f "$path/$address/diffURLs.txt" ];then
				rm -f $path/$address/diffURLs.txt
		fi
		touch $path/$address/diffURLs.txt

		comm -23 $path/$address/newURLs.txt $path/$address/URLs.txt > $path/$address/diffURLs.txt
		if [ -s "$path/$address/diffURLs.txt" ];then
			echo "Found new dirs for $address !"
			#cat $path/$address/diffURLs.txt
			cat $path/$address/diffURLs.txt >> $path/$address/URLs.txt
			#else
			#echo "New folders/files not found :^("
		fi

		rm -f $path/$address/newURLs.txt
		rm -f $path/$address/_*
		#rm -f $path/$address/httpx.result

	fi
done



export -f dedup_pics


echo "gowitness started working at" $(date)
rm -rf $path/info/gowitness
mkdir $path/info/gowitness
ls -1 $path/*/*.https | parallel --jobs 2 --timeout 5h "docker run --rm -v /mnt/reports/:/data/ leonjza/gowitness gowitness file -f {//}/URLs.txt --threads 2 --disable-db -P $path/info/gowitness/{/.} --resolution-x 1440 --resolution-y 900"
ls -1 $path/*/*.http | parallel --jobs 2 --timeout 5h "docker run --rm -v /mnt/reports/:/data/ leonjza/gowitness gowitness file -f {//}/URLs.txt --threads 2 --disable-db -P $path/info/gowitness/{/.} --resolution-x 1440 --resolution-y 900"
echo "gowitness completed at" $(date)


# pretty cool trick
# ls -1d $path/info/gowitness/* | parallel --jobs 1 --link 'dedup_pics {}'

rm -rf $path/info/screenshots_new
mkdir $path/info/screenshots_new
find $path/info/gowitness/*/ -type f -exec mv {} $path/info/screenshots_new \;
#rsync -avz --remove-source-files /path/to/unique/images/ /path/to/merged/images/


echo "difPy started working at" $(date)
dedup_pics 1000 $path/info/screenshots_new
if [[ $(find $path/info/screenshots_new/ -type f | wc -l) -gt 10000 ]]; then dedup_pics 5000 $path/info/screenshots_new ; fi
dedup_pics 0 $path/info/screenshots_new
echo "difPy completed at" $(date)


echo "Screenshots comparison started working at" $(date)
if [[ ! -d "$path/info/screenshots_trusted/" ]] ;then mkdir $path/info/screenshots_trusted/ ; fi
if [[ ! -d "$path/info/screenshots_diff/" ]] ;then mkdir $path/info/screenshots_diff/ ; fi

if [ ! -z "$(ls -A $path/info/screenshots_trusted/)" ];then
	# if the folder is not empty:
	# todo - delete parallel
	python3 pic_dedup.py -d "$path/info/screenshots_trusted/" "$path/info/screenshots_new/"	
	find $path/info/screenshots_new/ -type f -exec mv {} $path/info/screenshots_diff/ \;
    ls -d1 $path/info/screenshots_diff/*  | parallel --jobs 1 --delay 2 "python3 express_pic.py --p {} --t {/.}"
	python3 express_text.py -t "Появились новые скриншоты #${target}, нужно перетащить их в screenshots_trusted. Команда: mv -f --backup=numbered screenshots_diff/* screenshots_trusted/"
else
	# if the folder is empty:
	find $path/info/screenshots_new -type f -exec mv {} $path/info/screenshots_trusted/ \;
	ls -d1 $path/info/screenshots_trusted/*  | parallel --jobs 1 --delay 2 "python3 express_pic.py --p {} --t {/.}"
fi
echo "Screenshot comparison completed at" $(date)

# Shodan
# xargs -a $iplist -I % sh -c './cidr.sh % | nrich - | grep -B 4 Vulnerabilities && sleep 10' > $path/info/shodan.txt

#todo - add non web

#todo - add password bruteforce

#todo - add Nessus/Netsparker

#todo - add nmap scripts


echo "---------------------"
echo "Brutespray"
echo "---------------------"

sudo path="${path}" bash << EOF
if [[ -f $path/info/brutespray_status.done ]]; then sudo bash -c './scan_with_brutespray.sh $path > /dev/null &' && echo "Brutespray started" ; else echo "Brutespray not finished yet" ; fi
EOF
#todo - add 1) scan params 2)import of finded URLs 3) reports

echo "---------------------"
echo "Acunetix"
echo "---------------------"
# this code do a parallel scan
path="${path}" bash << EOF
if [[ -f $path/info/acunetix_status.done ]]; then bash -c './scan_with_acunetix.sh $path > /dev/null &' && echo "Acunetix started" ; else echo "Acunetix not finished yet" ; fi
EOF
# todo - add 1) scan params 2)import of finded URLs 3) reports


run_nuclei_scan() {
    local target=$1
    local crit=$2
	mkdir ${path}/info/nuclei_output/${target}
    # printf "${green}\n[$(date +'%Y-%m-%d %H:%M:%S')] Running: Nuclei $crit${reset}\n\n"
    echo $target | $nuclei -disable-update-check \
						   -retries 2 \
						   -severity $crit \
						   -nh \
						   -nc \
						   -rl 10 \
						   -o ${path}/info/nuclei_output/${target}/${crit}.txt
	# -dast \ -silent \
}

export path
export nuclei
export -f run_nuclei_scan
targets=$(ls -1 ${path})
severity_array=("info" "low" "medium" "high" "critical")
rm -rf ${path}/info/nuclei_output
mkdir -p ${path}/info/nuclei_output

parallel --progress \
         --timeout 10h \
         --delay 0.1 \
         --ll \
         --tag \
         --shuf \
		 --color \
         --joblog ${path}/info/nuclei_joblog.txt \
         --jobs 4 \
         --retries 1 \
         run_nuclei_scan ::: $targets ::: "${severity_array[@]}"
# --load 75% \ --memfree 0.5G \ --dry-run \ 


if [ -f "$path/info/nuclei_new.txt" ];then
	rm -f $path/info/nuclei_new.txt
fi

cat ${path}/info/nuclei_output/*/*.txt > ${path}/info/nuclei_new.txt
sort -u ${path}/info/nuclei_new.txt -o ${path}/info/nuclei_new.txt
python3 express_text.py -t "#${target} Nuclei total findings: $(cat ${path}/info/nuclei_new.txt | wc -l)"

if [ ! -f "${path}/info/nuclei.txt" ];then
	touch ${path}/info/nuclei.txt
	else
		sort -u ${path}/info/nuclei.txt -o ${path}/info/nuclei.txt
fi

rm -f ${path}/info/nuclei_diff.txt
touch ${path}/info/nuclei_diff.txt
comm -23 ${path}/info/nuclei_new.txt ${path}/info/nuclei.txt > ${path}/info/nuclei_diff.txt

if [ ! -s "${path}/info/nuclei.txt" ];then
	cat ${path}/info/nuclei_new.txt > ${path}/info/nuclei.txt
fi

if [ -s "${path}/info/nuclei_diff.txt" ];then
	echo "Found new nucleics!"
	cat ${path}/info/nuclei_diff.txt >>  ${path}/info/nuclei.txt
	sort -u  ${path}/info/nuclei.txt -o ${path}/info/nuclei.txt
	echo >> ${path}/info/nuclei_diff.txt
	echo "#nuclei #${target}" >> ${path}/info/nuclei_diff.txt
	python3 express_file.py --f "${path}/info/nuclei_diff.txt"

	else
	echo "New nucleics not found :^("
fi

python3 express_text.py -t "All tasks for #${target} is completed"