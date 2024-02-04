#!/bin/sh

set -ue

scriptdir=$(dirname -- "$(readlink -f -- "$0")")
source $scriptdir/disk.lib
source $scriptdir/benchmark.lib

DSTAT_TIMEFMT="%Y-%m-%d %H:%M:%S"
export DSTAT_TIMEFMT

target="sda"

FIO_OPTION="-p nvme"
DEVSIZE="192G"
FIOSIZE="8G"

ZFS_OPT='-O atime=off -O relatime=off -O xattr=sa -O dedup=off -O primarycache=none'

function fio_ext4 () {
    local benchname fio_option devsize fiosize devname diskpart info csv log ashift
    benchname="$1"
    fio_option="$2"
    devsize="$3"
    fiosize="$4"
    devname="$5"

    benchname="${benchname}-ext4-${devname}"
    echo "----------------------------------------------------------------------"
    msg "start ${benchname}"
    info=$(get_logfilename "${benchname}.info" txt)
    csv=$(get_logfilename "${benchname}.dstat" csv)
    log=$(get_logfilename "${benchname}.fio" log)
    print_disk_info ${devname} >> "${info}"

    create_gpt $devname ${devsize} 8300
    execute sleep 5
    diskpart="${devname}1"
    start_dstat "${csv}" ${devname}
    print_diskpart_info ${devname} >> "${info}"
    create_ext4 ${diskpart} >> "${info}"
    mount_ext4 ${diskpart} /${diskpart}
    print_ext4_info ${diskpart} >> "${info}"
    execute $scriptdir/fio-cdm ${fio_option} -s ${fiosize} -u -d /${diskpart} >> "${log}"
    kill_dstat
    umount_ext4 /${diskpart}
    wipe_devices ${devname}
}

function fio_zfs_compress () {
    local benchname fio_option poolname compress devsize fiosize devname diskpart info csv log ashift
    benchname="$1"
    fio_option="$2"
    poolname="$3"
    compress="$4"
    devsize="$5"
    fiosize="$6"
    devname="$7"

    benchname="${benchname}-zfs-${compress}-${devname}"
    echo "----------------------------------------------------------------------"
    msg "start ${benchname}"
    info=$(get_logfilename "${benchname}.info" txt)
    csv=$(get_logfilename "${benchname}.dstat" csv)
    log=$(get_logfilename "${benchname}.fio" log)
    print_disk_info ${devname} >> "${info}"

    create_gpt $devname ${devsize} BF01
    diskpart=$(get_partname $devname)
    # wait a while to zpool will be able to create a pool using the GPT name of a partition
    # 'blockdev --rereadpt' seems to have no effect to resolve this
    execute sleep 5
    ashift=$(get_ashift $(echo "${devname}" | cut -d' ' -f1))
    create_zfs zpool create -o ashift=${ashift} ${ZFS_OPT} \
        -O compression=${compress} \
        ${poolname} ${diskpart}

    start_dstat "${csv}" ${devname}
    print_diskpart_info ${devname} >> "${info}"
    print_zfs_info >> "${info}"
    execute $scriptdir/fio-cdm ${fio_option} -s ${fiosize} -u -d /${poolname} >> "${log}"
    kill_dstat
    destroy_zfs ${poolname}
    wipe_devices ${devname}
}


systeminfo=$(get_logfilename systeminfo txt)

print_system_info   >> "$systeminfo"
print_zfs_version   >> "$systeminfo"
print_zfs_benchmark >> "$systeminfo"
print_disk_info ${target}     >> "$systeminfo"
print_diskpart_info ${target} >> "$systeminfo"

benchname="fio_raw"
mkdir -p ${benchname}
(
    cd ${benchname}
    fio_raw "${benchname}" "${FIO_OPTION}" $FIOSIZE ${target}
    secure_erase ${target}
)

benchname="fio_ext4"
mkdir -p ${benchname}
(
    cd ${benchname}
    fio_ext4 "${benchname}" "${FIO_OPTION}" $DEVSIZE $FIOSIZE ${target}
    secure_erase ${target}
)

benchname="zfs_off"
mkdir -p ${benchname}
(
    cd ${benchname}
    fio_zfs_compress "${benchname}" "${FIO_OPTION}" zfspool off $DEVSIZE $FIOSIZE ${target}
    secure_erase ${target}
)

benchname="zfs_lz4"
mkdir -p ${benchname}
(
    cd ${benchname}
    fio_zfs_compress "${benchname}" "${FIO_OPTION}" zfspool lz4 $DEVSIZE $FIOSIZE ${target}
    secure_erase ${target}
)

benchname="zfs_gzip-6"
mkdir -p ${benchname}
(
    cd ${benchname}
    fio_zfs_compress "${benchname}" "${FIO_OPTION}" zfspool gzip-6 $DEVSIZE $FIOSIZE ${target}
    secure_erase ${target}
)

benchname="zfs_zstd-3"
mkdir -p ${benchname}
(
    cd ${benchname}
    fio_zfs_compress "${benchname}" "${FIO_OPTION}" zfspool zstd-3 $DEVSIZE $FIOSIZE ${target}
    secure_erase ${target}
)
