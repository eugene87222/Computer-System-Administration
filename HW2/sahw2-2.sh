#!/usr/bin/env bash

convert_unit() {
    unit=("B" "KB" "MB" "GB" "TB")
    unit_index=0
    base=1024
    mem=$1
    while [ $(bc <<< "${mem} > ${base}") -eq 1 ] ; do
        mem=$(bc <<< "scale=2; ${mem} / ${base}")
        ((unit_index += 1))
    done
    result="${mem} ${unit[${unit_index}]}"
    echo ${result}
}

ord() {
    LC_CTYPE=C printf '%d' "'$1"
}

SYS_INFO() {
    model=$(sysctl -n hw.model)
    machine=$(sysctl -n hw.machine)
    core=$(sysctl -n hw.ncpu)
    dialog --msgbox "CPU INFO\n\nCPU Model: ${model}\nCPU Machine: ${machine}\nCPU Core: ${core}" 30 70
}

MEMORY_INFO() {
    pagesize=$(sysctl -n hw.pagesize 2> /dev/null)
    unit=("B" "KB" "MB" "GB" "TB")
    base=1024
    
    total=$(sysctl -n hw.realmem 2> /dev/null)
    total_readable=${total:=10000000}
    total_readable=$(convert_unit ${total_readable})
    while true ; do
        free=$((`sysctl -n vm.stats.vm.v_free_count 2> /dev/null` * ${pagesize}))
        free_readable=${free:=5000000}
        free_readable=$(convert_unit ${free_readable})

        used=$((${total} - ${free}))
        used_readable=${used:=5000000}
        used_readable=$(convert_unit ${used_readable})

        progress=$((100 * ${used} / ${total}))
        dialog --mixedgauge "Memory Info and Usage\n\nTotal: ${total_readable}\nUsed: ${used_readable}\nFree: ${free_readable}" 30 70 ${progress}
        
        read -r -n 1 -t 2
        if [ $? -eq 0 ] && [ `ord "${REPLY}"` -eq 0 ] ; then
            break
        fi
    done
}

NETWORK_INFO() {
    while true ; do
        line_number=$(ifconfig | awk 'NF > 0' | grep -E '^[A-Za-z0-9]' | wc -l)
        if [ ${line_number} -lt 30 ] ; then
            line_number=30
        fi
        command=$(ifconfig | awk 'NF > 0' | grep -E '^[A-Za-z0-9]' | sed 's/://g' | awk 'BEGIN { printf "dialog --menu \"Network Interfaces\" 30 70 ${line_number} "; } { printf $1" \\* "; } END { printf "--output-fd 1" }')
        interface=$(eval "${command}")
        exitcode=$?
        if [ ${exitcode} -eq 1 ] ; then
            break
        elif [ ${exitcode} -eq 0 ] ; then
            ipv4=$(ifconfig ${interface} | grep -E 'inet ' | awk '{ printf $2; }')
            mask=$(ifconfig ${interface} | grep -E 'inet ' | awk '{ printf $4; }')
            MAC=$(ifconfig ${interface} | grep -E 'ether ' | awk '{ printf $2; }')
            dialog --msgbox "Interface Name: ${interface}\n\nIPv4___: ${ipv4:-}\nNetmask: ${mask:-}\nMAC____: ${MAC:-}" 30 70
        fi
    done
}

FILE_BROWSER() {
    while true ; do
        line_number=$(ls -la | grep -v '^total' | wc -l)
        if [ ${line_number} -lt 30 ] ; then
            line_number=30
        fi
        list=""
        current_dir=$(pwd)
        for elem in $(ls -la | grep -v '^total' | awk 'BEGIN { result = ""; start = 0; } { if ( start == 0 ) { result = result$9; start++; } else { result = result" "$9; } } END { print result; }') ; do
            list="${list} ${elem} $(file -i ${elem} | awk '{ print $2; }' | sed 's/;//g')"
        done
        selection=$(dialog --menu "File Browser: ${current_dir}" 30 70 ${line_number} ${list} --output-fd 1)
        exitcode=$?
        if [ ${exitcode} -eq 1 ] ; then
            break
        elif [ ${exitcode} -eq 0 ] ; then
            if [ "${selection}" == "." ] ; then
                :
            elif [ "${selection}" == ".." ] ; then
                cd ..
            else
                info=$(ls -la | grep -E " ${selection}$")
                if [ ${info:0:1} == 'd' ] ; then
                    cd "${selection}"
                elif [ ${info:0:1} == '-' ] ; then
                    file_info=$(file -b ${selection})
                    file_size=$(ls -l ${selection} | awk '{ print $5; }')
                    file_size=$(convert_unit ${file_size})
                    if [[ ${file_info} =~ "text" ]] ; then
                        while true ; do
                            dialog --extra-button --extra-label "Edit" --msgbox "<File Name>: ${selection}\n<File Info>: ${file_info}\n<File Size>: ${file_size}" 30 70
                            exitcode=$?
                            if [ ${exitcode} -eq 0 ] ; then
                                break
                            elif [ ${exitcode} -eq 3 ] ; then
                                $(echo "${EDITOR:-vi}") ${selection}
                            fi
                        done
                    else
                        dialog --msgbox "<File Name>: ${selection}\n<File Info>: ${file_info}\n<File Size>: ${file_size}" 30 70
                    fi
                fi
            fi
        fi
    done
}

CPU_LOADING() {
    while true ; do
        n=$(sysctl -n hw.ncpu)
        cpu_loading=$(top -b -s 1 -d 2 -P | grep -i '^CPU' | tail -n ${n} | sed 's/%//g' | awk 'BEGIN { total = 0; i = 0; printf "dialog --mixedgauge \"CPU Loading\\n"} { if( i != 0) { printf "\\n"; } printf "CPU"i": USER: "$3+$5"%% SYST: "$7"%% IDLE: "$9+$11"%%"; i++; total += ($9 + $11)} END { printf "\" 30 70 %.0f", 100 - total / i; }')
        eval "${cpu_loading}"
        read -r -n 1 -t 3
        if [ $? -eq 0 ] && [ `ord "${REPLY}"` -eq 0 ] ; then
            break
        fi
    done
}

while true ; do
    option=$(dialog --menu "SYS INFO" 30 70 30 1 "CPU INFO" 2 "MEMORY INFO" 3 "NETWORK INFO" 4 "FILE BROWSER" 5 "CPU LOADING" --output-fd 1)
    exitcode=$?
    if [ ${exitcode} -eq 1 ] ; then
        # cancel
        break
    elif [ ${exitcode} -eq 0 ] ; then
        if [ ${option} -eq 1 ] ; then
            SYS_INFO
        elif [ ${option} -eq 2 ] ; then
            MEMORY_INFO
        elif [ ${option} -eq 3 ] ; then
            NETWORK_INFO
        elif [ ${option} -eq 4 ] ; then
            FILE_BROWSER
        elif [ ${option} -eq 5 ] ; then
            CPU_LOADING
        fi
    fi
done