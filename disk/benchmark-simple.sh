#!/bin/sh

set -ue

scriptdir=$(dirname -- "$(readlink -f -- "$0")")
source $scriptdir/disk.lib
source $scriptdir/benchmark.lib

DSTAT_TIMEFMT="%Y-%m-%d %H:%M:%S"
export DSTAT_TIMEFMT

onboard="sda sdb sdc sdd"
sas3008="sde sdf sdg sdh sdi sdj sdk sdl"
all_devices="sda sdb sdc sdd sde sdf sdg sdh sdi sdj sdk sdl"

ARRAY1="sda sdb sdc sdd sde sdf"
ARRAY2="sdg sdh sdi sdj sdk sdl"

FIO_OPTION=""
DEVSIZE="128G"
FIOSIZE="64G"

ZFS_OPT='-O atime=off -O relatime=off -O xattr=sa -O dedup=off -O compression=off -O primarycache=none'


# 01 one by one device raw access
function fio_01 {
    local benchname fio_option fiosize info csv log
    benchname="fio-cdm-01"
    fio_option=$FIO_OPTION
    devsize=$DEVSIZE
    fiosize=$FIOSIZE

    mkdir -p ${benchname}
    (
        cd ${benchname}

        fio_raw "${benchname}" "${fio_option}" $fiosize ${all_devices}
    )
}

# 02 onboard SATA 4 ports mdraid
function fio_02 {
    local benchname fio_option devsize fiosize
    benchname="fio-cdm-02"
    fio_option=$FIO_OPTION
    devsize=$DEVSIZE
    fiosize=$FIOSIZE

    mkdir -p ${benchname}
    (
        cd ${benchname}

        exec_for_each_devices fio_md_raw "${benchname}" "${fio_option}" md0 0 $devsize $fiosize 4 ${onboard}
        exec_for_each_devices fio_md_raw "${benchname}" "${fio_option}" md0 1 $devsize $fiosize 4 ${onboard}
        exec_for_each_devices fio_md_raw "${benchname}" "${fio_option}" md0 5 $devsize $fiosize 4 ${onboard}
        exec_for_each_devices fio_md_raw "${benchname}" "${fio_option}" md0 6 $devsize $fiosize 4 ${onboard}

        exec_for_each_devices fio_md_ext4 "${benchname}" "${fio_option}" md0 0 $devsize $fiosize 4 ${onboard}
        exec_for_each_devices fio_md_ext4 "${benchname}" "${fio_option}" md0 1 $devsize $fiosize 4 ${onboard}
        exec_for_each_devices fio_md_ext4 "${benchname}" "${fio_option}" md0 5 $devsize $fiosize 4 ${onboard}
        exec_for_each_devices fio_md_ext4 "${benchname}" "${fio_option}" md0 6 $devsize $fiosize 4 ${onboard}
    )
}

# 03 LSI SAS3008 8 ports mdraid
function fio_03 {
    local benchname fio_option devsize fiosize
    benchname="fio-cdm-03"
    fio_option=$FIO_OPTION
    devsize=$DEVSIZE
    fiosize=$FIOSIZE

    mkdir -p ${benchname}
    (
        cd ${benchname}

        exec_for_each_devices fio_md_raw "${benchname}" "${fio_option}" md0 0 $devsize $fiosize 8 ${sas3008}
        exec_for_each_devices fio_md_raw "${benchname}" "${fio_option}" md0 1 $devsize $fiosize 8 ${sas3008}
        exec_for_each_devices fio_md_raw "${benchname}" "${fio_option}" md0 5 $devsize $fiosize 8 ${sas3008}
        exec_for_each_devices fio_md_raw "${benchname}" "${fio_option}" md0 6 $devsize $fiosize 8 ${sas3008}

        exec_for_each_devices fio_md_ext4 "${benchname}" "${fio_option}" md0 0 $devsize $fiosize 8 ${sas3008}
        exec_for_each_devices fio_md_ext4 "${benchname}" "${fio_option}" md0 1 $devsize $fiosize 8 ${sas3008}
        exec_for_each_devices fio_md_ext4 "${benchname}" "${fio_option}" md0 5 $devsize $fiosize 8 ${sas3008}
        exec_for_each_devices fio_md_ext4 "${benchname}" "${fio_option}" md0 6 $devsize $fiosize 8 ${sas3008}
    )
}

# 04 onboard and LSI SAS3008, 12 ports mdraid
function fio_04 {
    local benchname fio_option devsize fiosize
    benchname="fio-cdm-04"
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

# 05 onboard SATA 4 ports zfs
function fio_05 {
    local benchname fio_option devsize fiosize
    benchname="fio-cdm-05"
    fio_option=$FIO_OPTION
    devsize=$DEVSIZE
    fiosize=$FIOSIZE

    mkdir -p ${benchname}
    (
        cd ${benchname}

        exec_for_each_devices fio_zfs_simple "${benchname}" "${fio_option}" zfspool stripe $devsize $fiosize 4 ${onboard}
        exec_for_each_devices fio_zfs_simple "${benchname}" "${fio_option}" zfspool mirror $devsize $fiosize 4 ${onboard}
        exec_for_each_devices fio_zfs_simple "${benchname}" "${fio_option}" zfspool raidz $devsize $fiosize 4 ${onboard}
        exec_for_each_devices fio_zfs_simple "${benchname}" "${fio_option}" zfspool raidz2 $devsize $fiosize 4 ${onboard}
    )
}

# 06 LSI SAS3008 8 ports zfs
function fio_06 {
    local benchname fio_option devsize fiosize
    benchname="fio-cdm-06"
    fio_option=$FIO_OPTION
    devsize=$DEVSIZE
    fiosize=$FIOSIZE

    mkdir -p ${benchname}
    (
        cd ${benchname}

        exec_for_each_devices fio_zfs_simple "${benchname}" "${fio_option}" zfspool stripe $devsize $fiosize 8 ${sas3008}
        exec_for_each_devices fio_zfs_simple "${benchname}" "${fio_option}" zfspool mirror $devsize $fiosize 8 ${sas3008}
        exec_for_each_devices fio_zfs_simple "${benchname}" "${fio_option}" zfspool raidz $devsize $fiosize 8 ${sas3008}
        exec_for_each_devices fio_zfs_simple "${benchname}" "${fio_option}" zfspool raidz2 $devsize $fiosize 8 ${sas3008}
    )
}

# 07 onboard and LSI SAS3008, 12 ports zfs
function fio_07 {
    local benchname fio_option devsize fiosize
    benchname="fio-cdm-07"
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

# 08 mdraid + zfs
function fio_08 {
    local benchname fio_option devsize fiosize
    benchname="fio-cdm-08"
    fio_option=$FIO_OPTION
    devsize=$DEVSIZE
    fiosize=$FIOSIZE

    mkdir -p ${benchname}
    (
        cd ${benchname}

        exec_for_each_devices fio_md_zfs "${benchname}" "${fio_option}" md0 5 $devsize $fiosize 4 ${onboard}
        exec_for_each_devices fio_md_zfs "${benchname}" "${fio_option}" md0 5 $devsize $fiosize 8 ${sas3008}
        exec_for_each_devices fio_md_zfs "${benchname}" "${fio_option}" md0 5 $devsize $fiosize 12 ${all_devices}
    )
}

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

# 09 onboard SATA 4 ports raid and LSI SAS3008 8 ports raid to stripe
function fio_09 {
    local benchname fio_option devsize fiosize
    benchname="fio-cdm-09"
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

# 10 split onboard SATA 4 ports and LSI SAS3008 8 ports to 6 * 2
function fio_10 {
    local benchname fio_option devsize fiosize
    benchname="fio-cdm-10"
    poolname="zfspool"
    fio_option=$FIO_OPTION
    devsize=$DEVSIZE
    fiosize=$FIOSIZE


    mkdir -p ${benchname}
    (
        cd ${benchname}

        devices1="$ARRAY1"
        devices2="$ARRAY2"
        fio_zfs_stripe_of_raidz "${benchname}" "${fio_option}" zfspool $devsize $fiosize
        fio_mdraid5_to_zfs_stripe "${benchname}" "${fio_option}" zfspool $devsize $fiosize
    )
}



check_executable lscpu lsmem lspci lsblk udevadm blockdev fdisk gdisk \
    sgdisk mdadm tune2fs zfs wipefs pcp fio

systeminfo=$(get_logfilename systeminfo txt)

print_system_info >> "$systeminfo"
print_md_version  >> "$systeminfo"
print_zfs_version >> "$systeminfo"
print_disk_info ${all_devices}     >> "$systeminfo"
print_diskpart_info ${all_devices} >> "$systeminfo"

fio_01
fio_02
fio_03
fio_04
fio_05
fio_06
fio_07
fio_08
fio_09
fio_10
