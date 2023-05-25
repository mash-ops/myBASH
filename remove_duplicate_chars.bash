#!/bin/bash
#Prog: To remove repetative pattern and print unique elements in a string
#Auth: manjesh

#str="Hello"
#str="MMaannjjjjjeeeesshaaaaMMaannjj"
str="MMaannjjjjjeeeesshaaaaMMaannjjaaeejMananejsajj"

echo "Original String : $str"
size=${#str}
ind=0

echo -n "Duplicate characters in String Removed : "
declare -a array
declare -a narray
size=${#str}
while [ $size -ge "1" ]
do
  if [ $ind > 0 ]; then
    prev=${str:$ind-1:1}
    if [ $prev == ${str:$ind:1} ]; then
       size=$((size-1))
       ind=$((ind+1))
       continue
    fi
  fi
  #echo -n ${str:$ind:1}
  array[$ind]=${str:$ind:1}
  size=$((size-1))
  ind=$((ind+1))

done

#remove duplicate:
asize=${#array[@]}                       #size of the array
aind=0
found=0
#printf "%s" "${array[@]}"

while [ $asize -ge "1" ]                 #loop thru the elemnts of array
do
   seeking="${array[$aind]}"             #get element to compare in the new array
   if [[ "$seeking" == "" ]]; then       #when the element is blank
      aind=$((aind+1))                   #increment index count and continue to next index
      continue
   fi
   if [ $aind > 0 ]; then                #since index[0] is the first element
     for element in "${narray[@]}" ; do  #Check in element in the new array if already there
        if [[ $element == "$seeking" ]] 
        then
            found=1                      #if element found in the new array, set flag 
            break                        #and dont process/seek further elements
        fi
      done
    fi
    if [[ $found == 0 ]]; then           #if element is not found in new array then store
  	narray[$aind]=${array[$aind]}
  	asize=$((asize-1))
  	aind=$((aind+1))
        found=0
    else                                 #since the same element exists in new array, dont store
  	asize=$((asize-1))
  	aind=$((aind+1))
        found=0
    fi
done
#echo -n ${narray[@]}
printf "%s" "${narray[@]}" 
        

#tr ' ' '\n' <<< "${array[@]}" | sort -u | tr '\n' ' '
#tr ' ' '\n' <<< "${array[@]}" | uniq | tr '\n' ' '
#echo ${array[@]}|awk '!seen[$0]++' 
##awk '!uniq++' ${array[@]}
##echo "${array[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '
#echo ${array[@]}|awk '!uniq[$0]++' |uniq 
#echo $(printf "%s\n" "${array[@]}" | sort -u | tr '\n' ' ')
echo 
echo
