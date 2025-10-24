#!env bash
#Author : manjeshtm@gmail.com
#Purpose: Display Digital style clock using ascii char and system time
#
#

#------Check Current screen size
LINES=$(tput lines)
COLUMNS=$(tput cols)
if [[ "$COLUMNS" -lt 90 || "$LINES" -lt 15 ]]; then
   printf "Screen size is small to continue, Need a min of 15 x 90\nCurrent Lines : ${LINES}, Columns : ${COLUMNS} \n\n"
   exit 1
fi
#------Variables
zero="
 ░░░░░  
░     ░
░     ░
░     ░
░     ░
░     ░
 ░░░░░ "

one="
   ░   
   ░   
   ░   
   ░   
   ░   
   ░   
   ░  "

two="
 ░░░░░ 
      ░
      ░
 ░░░░░ 
░      
░      
 ░░░░░"

three="
 ░░░░░ 
      ░
      ░
 ░░░░░  
      ░ 
      ░ 
 ░░░░░ "

four="
░     ░
░     ░
░     ░
 ░░░░░ 
      ░ 
      ░ 
      ░"
five="
 ░░░░░ 
░       
░       
 ░░░░░  
      ░ 
      ░ 
 ░░░░░  "
six="
 ░░░░░ 
░      
░      
░░░░░░ 
░     ░ 
░     ░ 
 ░░░░░ "

seven="
 ░░░░░ 
      ░
      ░   
      ░
      ░ 
      ░ 
      ░"

eight=$(cat << 'EOF'
 ░░░░░ 
░     ░
░     ░   
 ░░░░░ 
░     ░ 
░     ░ 
 ░░░░░ 
EOF
)

nine=$(cat << 'EOF'
 ░░░░░ 
░     ░
░     ░   
 ░░░░░ 
      ░ 
      ░ 
 ░░░░░ 
EOF
)

dots="
      
      
  ░░  
      
  ░░  
      
     "
a="
 ░░░░░ 
░     ░
░░░░░░░ 
░     ░ 
░     ░" 

p="
 ░░░░░ 
░     ░
░░░░░░  
░       
░      " 

m="
 ░░ ░░ 
░  ░  ░
░  ░  ░   
░     ░ 
░     ░" 

ro=5
tput -S <<END
setb 0
setf 2
clear
civis
END
tput setaf 6  #foreground color
#tput setab 0  #background color
BOX_WIDTH=88
BOX_HEIGHT=12
START_ROW=1
START_COL=1

number_to_char=([0]=$zero [1]=$one [2]=$two [3]=$three [4]=$four [5]=$five 
                [6]=$six [7]=$seven [8]=$eight [9]=$nine)

declare -A ampm_to_char=([A]="$a" [M]="$m" [P]="$p")

OS_NAME=$(uname -s)
#------function
cleanup() {
    printf "\n\n\n"
    #echo "   Bye👋, Have a wonderful time..."
    tput cnorm # Ensure cursor is visible on exit
}
trap cleanup EXIT
tput clear
tput cup $START_ROW $START_COL

#------Print the frame for the digital clock
# Top border
printf "╔"
for ((i=0; i<$BOX_WIDTH-2; i++)); do
    printf "═"
done
printf "╗"

# Side borders and content area
for ((i=1; i<$BOX_HEIGHT-1; i++)); do
    tput cup $((START_ROW+i)) $START_COL
    printf "║"
    # Fill with spaces or content
    for ((j=0; j<$BOX_WIDTH-2; j++)); do
        printf " "
    done
    printf "║"
done

# Bottom border
tput cup $((START_ROW+BOX_HEIGHT-1)) $START_COL
printf "╚"
for ((i=0; i<$BOX_WIDTH-2; i++)); do
    printf "═"
done
printf "╝"

printf "\033]0;%s :: %s\007" "$(date)" "Digital Clock - Manjesh"
tput cup 1 15
printf "[ Digital Clock using system time : brought to you by Manjesh ]"

if [[ "${OS_NAME}" == "Darwin" ]]; then
   TIMEOUT=1
else
   TIMEOUT=0.5
fi

#------Main section for the digital clock
while [ true ];
do
  read -n 1 -s -t ${TIMEOUT} input
  if [[ -n "$input" ]]; then
     printf "\n\n\n\n"
     echo "   Bye👋, Have a wonderful time..."
     break
  fi
  time_format=$(date +'%I:%M:%S')
  #time_format=$(date +'%Y')
  IFS=':'
  read -r hour minute seconds <<< "$time_format"
  current_time="$hour$minute$seconds"
  ind=0
  col=5
  while [ "${ind}" -lt "${#current_time}" ]; do 
        substr=${current_time:$ind:1} ; 
        IFS=$'\n' read -r -d '' -a digital_display_lines <<< "${number_to_char[$substr]}"
        ro=5; #tput ed
       for line in "${digital_display_lines[@]}"; do
         printf "\e[${ro};${col}H%s" "$line"
         ((ro++))
       done
        #echo -n  "${number_to_char[$substr]}\t" ; ((ind++)); ((col+=8))
       if [[ "${ind}" == "1" || "${ind}" == "3" ]]; then
          ro=5; ((col+=8))
          IFS=$'\n' read -r -d '' -a digital_dot_lines <<< "${dots}"
          for dot_line in "${digital_dot_lines[@]}"; do
              printf "\e[${ro};${col}H%s" "$dot_line"
              ((ro++))
            done
            ((ind++)) ; ((col+=8)) 
       else
         ((ind++)) ; ((col+=8))
       fi
  done
      if [[ "${OS_NAME}" == "Darwin" ]]; then
          index=0 
	       ((col+=2))
	       am_pm=$(date +'%p')
	     while [ "${index}" -lt "${#am_pm}" ]; do
       		 substrg=${am_pm:$index:1}  
       		  if [[ "${substrg}" == "A" ]]; then
       		    IFS=$'\n' read -r -d '' -a digital_ampm_lines <<< "${a}"
       		 elif [[ "${substrg}" == "M" ]]; then
       		    IFS=$'\n' read -r -d '' -a digital_ampm_lines <<< "${m}"
       		 elif [[ "${substrg}" == "P" ]]; then
       		    IFS=$'\n' read -r -d '' -a digital_ampm_lines <<< "${p}"
       		 fi
       		 ro=6; 
       		 for ampm_line in "${digital_ampm_lines[@]}"; do
       		     printf "\e[${ro};${col}H%s" "${ampm_line}"
       		       ((ro++))
       		 done
		     ((index++)) ; ((col+=8))
	      done #am_pm
     else
      	am_pm=$(date +'%p')
      	index=0; ((col+=2))
      	while [ "${index}" -lt "${#am_pm}" ]; do
            substrg=${am_pm:$index:1}
            IFS=$'\n' read -r -d '' -a digital_ampm_lines <<< "${ampm_to_char[$substrg]}"
            ro=6 
            for ampm_line in "${digital_ampm_lines[@]}"; do
               printf "\e[${ro};${col}H%s" "$ampm_line"
               ((ro++))
            done
            ((index++)); ((col+=8))
      	done # am_pm
     fi
done

