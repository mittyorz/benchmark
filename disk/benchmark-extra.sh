#!/bin/sh

set -ue

scriptdir=$(dirname -- "$(readlink -f -- "$0")")
source $scriptdir/disk.lib
source $scriptdir/benchmark.lib

DSTAT_TIMEFMT="%Y-%m-%d %H:%M:%S"
export DSTAT_TIMEFMT

onboard="sda sdb sdc sdd sde sdf"
sas3008="sdg sdh sdi sdj sdk sdl"
all_devices="sda sdb sdc sdd sde sdf sdg sdh sdi sdj sdk sdl"

FIO_OPTION=""
DEVSIZE="128G"
FIOSIZE="64G"

ZFS_OPT='-O atime=off -O relatime=off -O xattr=sa -O dedup=off -O compression=off -O primarycache=none'


function fio_zfs_stripe_of_raidz () {
    local benchname fio_option poolname devsize fiosize dev info csv log
    local diskparts1 diskparts2 devnum1 devnum2
    # use global variable $devices1 $devices2
    benchname="$1"
    fio_option="$2"
    poolname="$3"
    devsize="$4"
    fiosize="$5"

    # number of devices is "number of spaces" + 1
    devnum1=$(expr 1 + $(echo ${devices1} | tr -cd ' \t' | wc -c))
    devnum2=$(expr 1 + $(echo ${devices2} | tr -cd ' \t' | wc -c))

    benchname="${benchname}-zfs-stripe_of_raidz-disk${devnum1}-${devnum2}"
    echo "----------------------------------------------------------------------"
    msg "start ${benchname}"
    info=$(get_logfilename "${benchname}.info" txt)
    csv=$(get_logfilename "${benchname}.dstat" csv)
    log=$(get_logfilename "${benchname}.fio" log)
    print_disk_info ${devices1} ${devices2} >> "${info}"
    diskparts1=""
    for dev in ${devices1}; do
        create_gpt $dev ${devsize} BF01
        diskparts1="${diskparts1} $(get_partname $dev)"
    done
    diskparts2=""
    for dev in ${devices2}; do
        create_gpt $dev ${devsize} BF01
        diskparts2="${diskparts2} $(get_partname $dev)"
    done
    execute sleep 5
    ashift=$(get_ashift $(echo "${devices1}" | cut -d' ' -f1))
    create_zfs zpool create -o ashift=${ashift} ${ZFS_OPT} \
        ${poolname} raidz ${diskparts1} raidz ${diskparts2}
    start_dstat "${csv}" ${devices1} ${devices2}
    print_diskpart_info ${devices1} ${devices2} >> "${info}"
    print_zfs_info >> "${info}"
    execute $scriptdir/fio-cdm ${fio_option} -s ${fiosize} -u -d /${poolname} >> "${log}"
    kill_dstat
    destroy_zfs ${poolname}
    wipe_devices ${devices1} ${devices2}
}

function fio_mdraid5_to_zfs_stripe () {
    local benchname fio_option poolname devsize fiosize dev info csv log
    local diskparts1 diskparts2 devnum1 devnum2
    # use global variable $devices1 $devices1
    benchname="$1"
    fio_option="$2"
    poolname="$3"
    devsize="$4"
    fiosize="$5"

    # number of devices is "number of spaces" + 1
    devnum1=$(expr 1 + $(echo ${devices1} | tr -cd ' \t' | wc -c))
    devnum2=$(expr 1 + $(echo ${devices2} | tr -cd ' \t' | wc -c))

    benchname="${benchname}-mdraid5-to-zfs-stripe-disk${devnum1}-${devnum2}"
    echo "----------------------------------------------------------------------"
    msg "start ${benchname}"
    info=$(get_logfilename "${benchname}.info" txt)
    csv=$(get_logfilename "${benchname}.dstat" csv)
    log=$(get_logfilename "${benchname}.fio" log)
    print_disk_info ${devices1} ${devices2} >> "${info}"
    create_md md0 5 ${devsize} ${devices1}
    create_md md1 5 ${devsize} ${devices2}
    start_dstat_md1 "${csv}" md0 md1 ${devices1} ${devices2}
    wait_md_syncing md0 md1
    print_diskpart_info ${devices1} ${devices2} >> "${info}"
    print_md_info md0 >> "${info}"
    print_md_info md1 >> "${info}"

    ashift=$(get_ashift md0)
    create_zfs zpool create -o ashift=${ashift} ${ZFS_OPT} \
        ${poolname} md0 md1
    print_zfs_info >> "${info}"
    execute $scriptdir/fio-cdm ${fio_option} -s ${fiosize} -u -d /${poolname} >> "${log}"
    kill_dstat
    destroy_zfs ${poolname}

    wipe_devices md0 md1
    destroy_md md0
    destroy_md md1
    wipe_devices ${devices1} ${devices2}
}

# 11 onboard SATA 4 + 2 ports
## one by one device raw access
function fio_11 {
    local benchname fio_option devsize fiosize
    benchname="fio-cdm-11"
    fio_option=$FIO_OPTION
    devsize=$DEVSIZE
    fiosize=$FIOSIZE

    mkdir -p ${benchname}
    (
        cd ${benchname}

        fio_raw "${benchname}" "${fio_option}" $fiosize ${all_devices}
    )
}

## 12_1 onboard SATA 4 + 2 ports mdraid
function fio_12_1 {
    local benchname fio_option devsize fiosize
    benchname="fio-cdm-12_1"
    fio_option=$FIO_OPTION
    devsize=$DEVSIZE
    fiosize=$FIOSIZE

    mkdir -p ${benchname}
    (
        cd ${benchname}

        exec_for_each_devices fio_md_raw "${benchname}" "${fio_option}" md0 0 $devsize $fiosize 6 ${onboard}
        exec_for_each_devices fio_md_raw "${benchname}" "${fio_option}" md0 1 $devsize $fiosize 6 ${onboard}
        exec_for_each_devices fio_md_raw "${benchname}" "${fio_option}" md0 5 $devsize $fiosize 6 ${onboard}
        exec_for_each_devices fio_md_raw "${benchname}" "${fio_option}" md0 6 $devsize $fiosize 6 ${onboard}

        exec_for_each_devices fio_md_ext4 "${benchname}" "${fio_option}" md0 0 $devsize $fiosize 6 ${onboard}
        exec_for_each_devices fio_md_ext4 "${benchname}" "${fio_option}" md0 1 $devsize $fiosize 6 ${onboard}
        exec_for_each_devices fio_md_ext4 "${benchname}" "${fio_option}" md0 5 $devsize $fiosize 6 ${onboard}
        exec_for_each_devices fio_md_ext4 "${benchname}" "${fio_option}" md0 6 $devsize $fiosize 6 ${onboard}
    )
}

## 12_2 onboard SATA 4 + 2 ports zfs
function fio_12_2 {
    local benchname fio_option devsize fiosize
    benchname="fio-cdm-12_2"
    fio_option=$FIO_OPTION
    devsize=$DEVSIZE
    fiosize=$FIOSIZE

    mkdir -p ${benchname}
    (
        cd ${benchname}

        exec_for_each_devices fio_zfs_simple "${benchname}" "${fio_option}" zfspool stripe $devsize $fiosize 6 ${onboard}
        exec_for_each_devices fio_zfs_simple "${benchname}" "${fio_option}" zfspool mirror $devsize $fiosize 6 ${onboard}
        exec_for_each_devices fio_zfs_simple "${benchname}" "${fio_option}" zfspool raidz $devsize $fiosize 6 ${onboard}
        exec_for_each_devices fio_zfs_simple "${benchname}" "${fio_option}" zfspool raidz2 $devsize $fiosize 6 ${onboard}
    )
}

# 13_1 LSI SAS3008 6 ports mdraid
function fio_13_1 {
    local benchname fio_option devsize fiosize
    benchname="fio-cdm-13_1"
    fio_option=$FIO_OPTION
    devsize=$DEVSIZE
    fiosize=$FIOSIZE


    mkdir -p ${benchname}
    (
        cd ${benchname}

        exec_for_each_devices fio_md_raw "${benchname}" "${fio_option}" md0 0 $devsize $fiosize 6 ${sas3008}
        exec_for_each_devices fio_md_raw "${benchname}" "${fio_option}" md0 1 $devsize $fiosize 6 ${sas3008}
        exec_for_each_devices fio_md_raw "${benchname}" "${fio_option}" md0 5 $devsize $fiosize 6 ${sas3008}
        exec_for_each_devices fio_md_raw "${benchname}" "${fio_option}" md0 6 $devsize $fiosize 6 ${sas3008}

        exec_for_each_devices fio_md_ext4 "${benchname}" "${fio_option}" md0 0 $devsize $fiosize 6 ${sas3008}
        exec_for_each_devices fio_md_ext4 "${benchname}" "${fio_option}" md0 1 $devsize $fiosize 6 ${sas3008}
        exec_for_each_devices fio_md_ext4 "${benchname}" "${fio_option}" md0 5 $devsize $fiosize 6 ${sas3008}
        exec_for_each_devices fio_md_ext4 "${benchname}" "${fio_option}" md0 6 $devsize $fiosize 6 ${sas3008}
    )
}

# 13_2 LSI SAS3008 6 ports mdraid
function fio_13_2 {
    local benchname fio_option devsize fiosize
    benchname="fio-cdm-13_2"
    fio_option=$FIO_OPTION
    devsize=$DEVSIZE
    fiosize=$FIOSIZE


    mkdir -p ${benchname}
    (
        cd ${benchname}

        exec_for_each_devices fio_zfs_simple "${benchname}" "${fio_option}" zfspool stripe $devsize $fiosize 6 ${sas3008}
        exec_for_each_devices fio_zfs_simple "${benchname}" "${fio_option}" zfspool mirror $devsize $fiosize 6 ${sas3008}
        exec_for_each_devices fio_zfs_simple "${benchname}" "${fio_option}" zfspool raidz $devsize $fiosize 6 ${sas3008}
        exec_for_each_devices fio_zfs_simple "${benchname}" "${fio_option}" zfspool raidz2 $devsize $fiosize 6 ${sas3008}
    )
}

# 14_1 onboard and LSI SAS3008, 12 ports mdraid
function fio_14_1 {
    local benchname fio_option devsize fiosize
    benchname="fio-cdm-14_1"
    fio_option=$FIO_OPTION
    devsize=$DEVSIZE
    fiosize=$FIOSIZE

    mkdir -p ${benchname}
    (
        cd ${benchname}

        exec_for_each_devices fio_md_raw "${benchname}" "${fio_option}" md0 0 $devsize $fiosize 12 ${all_devices}
        exec_for_each_devices fio_md_raw "${benchname}" "${fio_option}" md0 1 $devsize $fiosize 12 ${all_devices}
        exec_for_each_devices fio_md_raw "${benchname}" "${fio_option}" md0 5 $devsize $fiosize 12 ${all_devices}
        exec_for_each_devices fio_md_raw "${benchname}" "${fio_option}" md0 6 $devsize $fiosize 12 ${all_devices}

        exec_for_each_devices fio_md_ext4 "${benchname}" "${fio_option}" md0 0 $devsize $fiosize 12 ${all_devices}
        exec_for_each_devices fio_md_ext4 "${benchname}" "${fio_option}" md0 1 $devsize $fiosize 12 ${all_devices}
        exec_for_each_devices fio_md_ext4 "${benchname}" "${fio_option}" md0 5 $devsize $fiosize 12 ${all_devices}
        exec_for_each_devices fio_md_ext4 "${benchname}" "${fio_option}" md0 6 $devsize $fiosize 12 ${all_devices}
    )
}

# 14_2 onboard and LSI SAS3008, 12 ports zfs
function fio_14_2 {
    local benchname fio_option devsize fiosize
    benchname="fio-cdm-14_2"
    fio_option=$FIO_OPTION
    devsize=$DEVSIZE
    fiosize=$FIOSIZE

    mkdir -p ${benchname}
    (
        cd ${benchname}

        exec_for_each_devices fio_zfs_simple "${benchname}" "${fio_option}" zfspool stripe $devsize $fiosize 12 ${all_devices}
        exec_for_each_devices fio_zfs_simple "${benchname}" "${fio_option}" zfspool mirror $devsize $fiosize 12 ${all_devices}
        exec_for_each_devices fio_zfs_simple "${benchname}" "${fio_option}" zfspool raidz $devsize $fiosize 12 ${all_devices}
        exec_for_each_devices fio_zfs_simple "${benchname}" "${fio_option}" zfspool raidz2 $devsize $fiosize 12 ${all_devices}
    )
}

# 14_3 onboard and LSI SAS3008, 12 ports mdraid + zfs
function fio_14_3 {
    local benchname fio_option devsize fiosize
    benchname="fio-cdm-14_3"
    fio_option=$FIO_OPTION
    devsize=$DEVSIZE
    fiosize=$FIOSIZE

    mkdir -p ${benchname}
    (
        cd ${benchname}

        exec_for_each_devices fio_md_zfs "${benchname}" "${fio_option}" md0 5 $devsize $fiosize 12 ${all_devices}
    )
}

# 14_4 onboard SATA 4 + 2 ports and LSI SAS3008 6 ports to 6 * 2 raid + stripe
function fio_14_4 {
    local benchname fio_option devsize fiosize
    benchname="fio-cdm-14_4"
    poolname="zfspool"
    fio_option=$FIO_OPTION
    devsize=$DEVSIZE
    fiosize=$FIOSIZE


    mkdir -p ${benchname}
    (
        cd ${benchname}

        devices1="$onboard"
        devices2="$sas3008"
        fio_zfs_stripe_of_raidz "${benchname}" "${fio_option}" zfspool $devsize $fiosize
        fio_mdraid5_to_zfs_stripe "${benchname}" "${fio_option}" zfspool $devsize $fiosize
    )
}



check_executable lscpu lsmem lspci lsblk udevadm blockdev fdisk gdisk \
    sgdisk mdadm tune2fs zfs wipefs pcp fio

systeminfo=$(get_logfilename systeminfo txt)

print_system_info > "$systeminfo"
print_md_version  > "$systeminfo"
print_zfs_version > "$systeminfo"
print_disk_info ${all_devices}     > "$systeminfo"
print_diskpart_info ${all_devices} > "$systeminfo"

fio_11
fio_12_1
fio_12_2
fio_13_1
fio_13_2
fio_14_1
fio_14_2
fio_14_3
fio_14_4
