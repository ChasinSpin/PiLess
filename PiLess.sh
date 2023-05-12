#!/bin/sh

# LICENSE: GPL-2.0 License
# Copyright: Mark Simpson, 2023
# Contact: @ChasinSpin

E2FSCK_EXTFS="./e2fsck"
RESIZE2FS_EXTFS="./resize2fs"

if [ $# != 1 ];then
	echo "Usage: $0 imagename"
	echo "e.g.: $0 myNewRaspberryPiImage"
	exit 1	
fi

IMAGENAME="$1"
BOOTFS="/Volumes/bootfs"
DISKUTIL="/usr/sbin/diskutil"

COMPRESSOR=`/usr/bin/which xz`
if [ -z "$COMPRESSOR" ];then
	COMPRESSOR="/usr/bin/bzip2"
	COMPRESSOR_ARG="-c"
	COMPRESSOR_EXT="bz2"
else
	COMPRESSOR_ARG="-z7"
	COMPRESSOR_EXT="xz"
fi

FDISK="/usr/sbin/fdisk"
TMP_FILE="/tmp/piless.tmp.$$"
TMP_FILE2="/tmp/piless.tmp2.$$"


echo "********** IMPORTANT WARNING **********"
echo "THIS UTILITY WILL CHANGE THE SD CARD PROVIDED, AND MAY CORRUPT OTHER DISKS CONNECTED TO YOUR SYSTEM"
echo "USE AT YOUR OWN RISK!"
echo "This utility will:"
echo "   Shrink the Linux Partitition on the SD Card on and partition table"
echo "	 Alter ${BOOTFS}/cmdline.txt to allow for automatic resizing on next boot"

echo
/usr/bin/printf "Continue (Y/n): "
read line
if [ "$line" != "Y" ];then
	echo "Aborted..."
	exit 2
fi

if [ `/usr/bin/id -un` != "root" ];then
	echo "This utility must be run as root or with sudo"
	echo "Aborting..."
	exit 3
fi

echo
echo "I need to find your SD Card, if you've already connected it, eject and remove first so I can auto detect."
/usr/bin/printf "Ready? (Y/n): "
read line
if [ "$line" != "Y" ];then
	echo "Aborted..."
	exit 2
fi

"$DISKUTIL" list | grep "/dev" > "$TMP_FILE"

echo
echo "Now insert your SD Card, wait 30 seconds (or until the OS sees the SD Card) and continue."
/usr/bin/printf "Continue (Y/n): "
read line
if [ "$line" != "Y" ];then
	echo "Aborted..."
	exit 2
fi

"$DISKUTIL" list | grep "/dev" > "$TMP_FILE2"

DISK=`/usr/bin/diff "$TMP_FILE" "$TMP_FILE2" | /usr/bin/grep "/dev" | /usr/bin/sed "s/> //" | /usr/bin/cut -f1 -d " "`

if [ -z "$DISK" ];then
	echo "Error: SD Card not found, please wait for disk to be recognized before continuing, aborting..."
	exit 6
fi

LINUX_PART="${DISK}s2"

echo
echo "I will shrink: "
echo "   Device:                    $DISK"
"$DISKUTIL" info "$DISK" | /usr/bin/egrep "Media Name|Removable Media|Disk\ Size|Location"

echo
/usr/bin/printf "Is this the correct device? (Y/n): "
read line
if [ "$line" != "Y" ];then
	echo "Aborted..."
	exit 2
fi

echo
echo
/usr/bin/printf "Last chance, about to write SD Card, okay? (Y/n): "
read line
if [ "$line" != "Y" ];then
	echo "Aborted..."
	exit 2
fi

echo "# Unmounting all SD Card partitions"
"$DISKUTIL" unmountDisk "$DISK"

echo
echo "# Mounting ${BOOTFS}"
"$DISKUTIL" mountDisk "$DISK"
if [ ! -d "$BOOTFS" ];then
	echo "Error: ${BOOTFS} not mounted"
	"$DISKUTIL" unmountDisk "$DISK"
	exit 4
fi

echo
echo "# Checking for FAT and Linux partitions"
"$FDISK" -d "$DISK" > "$TMP_FILE"
LINE1_ID=`/usr/bin/head -1 "$TMP_FILE" | /usr/bin/cut -f3 -d,`
LINE2_ID=`/usr/bin/head -2 "$TMP_FILE" | /usr/bin/tail -1 | /usr/bin/cut -f3 -d,`
if [ "$LINE1_ID" != "0x0C" ];then
	echo "Error: Partition 1 is not a MSDOS partition, is this a Raspberry Pi System SD Card?, aborting..."
	exit 7
fi
if [ "$LINE2_ID" != "0x83" ];then
	echo "Error: Partition 2 is not a Linux partition, is this a Raspberry Pi System SD Card?, aborting..."
	exit 7
fi

echo
echo "# Checking we're not already shrunk"
TMP=`/usr/bin/grep "init=/usr/lib/raspberrypi-sys-mods/firstboot" "${BOOTFS}/cmdline.txt"`
if [ ! -z "$TMP" ];then
	echo "Error: SD Card is already shrunk, firstboot found in cmdline.txt"
	"$DISKUTIL" unmountDisk "$DISK"
	exit 5
fi

echo
echo "# Checking filesystem with e2fsck -f"
echo "$E2FSCK_EXTFS" -f "$LINUX_PART"
"$E2FSCK_EXTFS" -f "$LINUX_PART"
if [ "$?" != 0 ];then
	echo "Error: e2fsck failed"
	"$DISKUTIL" unmountDisk "$DISK"
	exit 6
fi

echo
echo "# Shrinking Filesystem resize2fs -M -p"
echo "$RESIZE2FS_EXTFS" -M -p "$LINUX_PART"
"$RESIZE2FS_EXTFS" -M -p "$LINUX_PART" 2>&1 | /usr/bin/tee "$TMP_FILE"
if [ "$?" != 0 ];then
	echo "Error: resize2fs failed"
	"$DISKUTIL" unmountDisk "$DISK"
	exit 6
fi
NEW_LENGTH=`/usr/bin/tail -2 "$TMP_FILE" | /usr/bin/head -1 | /usr/bin/grep "is now" | /usr/bin/cut -f7 -d" "`
echo "# Linux partition shrunk to: "`echo "${NEW_LENGTH} * 4096" | /usr/bin/bc -l`" bytes"
NEW_LENGTH=`echo "${NEW_LENGTH} * 8" | /usr/bin/bc -l`

echo
echo "# Get Original Linux Partition Size"
PART_SIZE=`"$FDISK" -d "$DISK" | /usr/bin/head -n 2 | /usr/bin/tail -1 | /usr/bin/cut -f2 -d,`

echo
echo "# Changing Linux partition size from ${PART_SIZE} to ${NEW_LENGTH} 512 byte blocks"
echo "# Ignore the following error: fdisk: could not open MBR file /usr/standalone/i386/boot0: No such file or directory"
"$DISKUTIL" unmountDisk "$DISK"

echo
echo "# Original partition table:"
"$FDISK" -d "$DISK"

cat <<EOF >"$TMP_FILE2"
edit 2



NEW_PARTITION_SIZE
write
y
quit
EOF

sed "s/NEW_PARTITION_SIZE/${NEW_LENGTH}/" "$TMP_FILE2" > "$TMP_FILE"

/bin/cat "$TMP_FILE" | "$FDISK" -e "$DISK"

echo "# New partition table..."
"$FDISK" -d "$DISK"
"$DISKUTIL" mountDisk "$DISK"

echo
echo "# Changing /bootfs/cmdline.txt to resize on boot..."
NEW_CMDLINE=`/bin/cat "${BOOTFS}/cmdline.txt" | /usr/bin/sed "s/$/ init=\/usr\/lib\/raspberrypi-sys-mods\/firstboot/"`
echo "$NEW_CMDLINE" > "${BOOTFS}/cmdline.txt"

echo
echo "# Determining image size..."
IMG_SIZE=`"$FDISK" -d /dev/disk9 | /usr/bin/head -2 | /usr/bin/tail -1 | /usr/bin/cut -f1,2 -d, | /usr/bin/sed "s/,/ + /" | /usr/bin/bc -l`
echo "Image Size (512 byte blocks): $IMG_SIZE"


echo
echo "# Backing up image, please wait..."
"$DISKUTIL" unmountDisk "$DISK"
OUTPUT_IMAGE_COMPRESSED="${IMAGENAME}.img.${COMPRESSOR_EXT}"
/bin/date
/bin/dd if="$DISK" bs=512 count="$IMG_SIZE" status=progress | "$COMPRESSOR" "$COMPRESSOR_ARG" > "$OUTPUT_IMAGE_COMPRESSED"
/bin/date

echo
echo "Finished writing: $OUTPUT_IMAGE_COMPRESSED"
echo "Now eject SD Card"

/bin/rm -f "$TMP_FILE" "$TMP_FILE2"

exit 0
