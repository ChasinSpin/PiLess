# PiLess

## Introduction
PiLess is a macOS bash shell script to create a "shrunk" image of a Raspberry Pi system SD Card which can be copied to other SD Cards or restored. It does this by leveraging the Pi's ability to expand a filesystem to fit the SD Card automatically on boot.  It is similar in concept to shrinking implemented by [ApplePiBaker](https://www.tweaking4all.com/software/macosx-software/macosx-apple-pi-baker/), [SD Clone (no longer available)](https://twocanoes.com/products/) and [PiShrink](https://github.com/Drewsif/PiShrink)

#### Features:

* Runs on macOS
* Shrinks the Linux Partition to minimum size in place
* Instructs Raspberry Pi to expand to fit SD Card on next insertion by amending /boot/cmdline.txt
* Works with recent Raspberry Pi System Images (/boot and Linux Partition)
* Doesn't require additional hard disk space (only space for final compressed image)
* Images are compressed with bzip2
* Works with xz compressor if installed
* Fast

#### Disclaimer

* Use at your own risk, it works for me, but may not work for you
* It will alter your SD Card (resize the fs, partition) and update cmdline.txt for the backup
* Your ssh keys will be regeneated next time you login
* It may corrupt your system drives if something goes wrong
* Limited error checking
* Only use of Raspberry Pi System SD Cards (e.g. bullseye)

#### Requirements

* macOS
* SD Card
* Raspberry Pi
* e2fsck & resize2fs
	* This can be obtained from [e2fsprogs](https://sourceforge.net/projects/e2fsprogs/), it is also included in this repository
	* License: GNU Public License version 2 and GNU Library
General Public License Version 2 (see NOTICE [e2fsprogs](https://sourceforge.net/projects/) )



## Installation
	cd
	git clone https://github.com/ChasinSpin/PiLess.git
	cd PiLess
	chmod u+x PiLess.sh
	
	
## Running
	cd ~/PiLess
	sudo ./PiLess.sh myNewImageFile


## Testing

* Write Raspios "Bullseye" img.xz to SD Card using [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
* Place SD Card in Raspberry Pi, boot (automatically expands to fill SD Card during boot)
* Login to verify operation
* sudo poweroff
* wait before removing power until all card activity (green light) has ceased, this can take 10-15mins
* cd ~/PiLess
* sudo ./PiLess.sh myNewImageFile
* Insert SD Card when prompted
* bzunzip2 myNewImageFile.img.bz2
* Write myNewImageFile.img to SD Card using [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
* Place SD Card in Raspberry Pi, boot (automatically expands to fill SD Card during boot)
* Login to verify operation and that the restore was successful (note ssh keys will have been regenerated)

Note: If using xz compressor, then img doesn't have to be "unzip" before burning with [Raspberry Pi Imager](https://www.raspberrypi.com/software/)


## Testing Output

	(base) Yoda:PiLess zawie$ sudo ./Piless.sh myNewImageFile
	Password:
	********** IMPORTANT WARNING **********
	THIS UTILITY WILL CHANGE THE SD CARD PROVIDED, AND MAY CORRUPT OTHER DISKS CONNECTED TO YOUR SYSTEM
	USE AT YOUR OWN RISK!
	This utility will:
	   Shrink the Linux Partitition on the SD Card on and partition table
		 Alter /Volumes/bootfs/cmdline.txt to allow for automatic resizing on next boot
	
	Continue (Y/n): Y
	
	I need to find your SD Card, if you've already connected it, eject and remove first so I can auto detect.
	Ready? (Y/n): Y
	
	Now insert your SD Card, wait 30 seconds (or until the OS sees the SD Card) and continue.
	Continue (Y/n): Y
	
	I will shrink: 
	   Device:                    /dev/disk9
	   Device / Media Name:       USB3.0 CRW-SD
	   Disk Size:                 127.9 GB (127865454592 Bytes) (exactly 249737216 512-Byte-Units)
	   Device Location:           External
	   Removable Media:           Removable
	
	Is this the correct device? (Y/n): Y
	
	
	Last chance, about to write SD Card, okay? (Y/n): Y
	# Unmounting all SD Card partitions
	Unmount of all volumes on disk9 was successful
	
	# Mounting /Volumes/bootfs
	Volume(s) mounted successfully
	
	# Checking for FAT and Linux partitions
	
	# Checking we're not already shrunk
	
	# Checking filesystem with e2fsck -f
	./e2fsck -f /dev/disk9s2
	e2fsck 1.47.0 (5-Feb-2023)
	Pass 1: Checking inodes, blocks, and sizes
	Pass 2: Checking directory structure
	Pass 3: Checking directory connectivity
	Pass 4: Checking reference counts
	Pass 5: Checking group summary information
	rootfs: 121760/7760160 files (0.1% non-contiguous), 1321181/31150592 blocks
	
	# Shrinking Filesystem resize2fs -M -p
	./resize2fs -M -p /dev/disk9s2
	resize2fs 1.47.0 (5-Feb-2023)
	Resizing the filesystem on /dev/disk9s2 to 941823 (4k) blocks.
	Begin pass 2 (max = 38282)
	Relocating blocks             XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
	Begin pass 3 (max = 951)
	Scanning inode table          XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
	Begin pass 4 (max = 10338)
	Updating inode references     XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
	The filesystem on /dev/disk9s2 is now 941823 (4k) blocks long.
	
	# Linux partition shrunk to: 3857707008 bytes
	
	# Get Original Linux Partition Size
	
	# Changing Linux partition size from 249204736 to 7534584 512 byte blocks
	# Ignore the following error: fdisk: could not open MBR file /usr/standalone/i386/boot0: No such file or directory
	Unmount of all volumes on disk9 was successful
	
	# Original partition table:
	8192,524288,0x0C,-,64,0,1,1023,3,32
	532480,249204736,0x83,-,1023,3,32,1023,63,32
	0,0,0x00,-,0,0,0,0,0,0
	0,0,0x00,-,0,0,0,0,0,0
	fdisk: could not open MBR file /usr/standalone/i386/boot0: No such file or directory
	Enter 'help' for information
	fdisk: 1>          Starting       Ending
	 #: id  cyl  hd sec -  cyl  hd sec [     start -       size]
	------------------------------------------------------------------------
	 2: 83 1023   3  32 - 1023  63  32 [    532480 -  249204736] Linux files*
	Partition id ('0' to disable)  [0 - FF]: [83] (? for help) Do you wish to edit in CHS mode? [n] Partition offset [0 - 249737216]: [532480] Partition size [1 - 249204736]: [249204736] fdisk:*1> Writing MBR at offset 0.
	fdisk: 1> Invalid command 'y'.  Try 'help'.
	fdisk: 1> # New partition table...
	8192,524288,0x0C,-,64,0,1,1023,3,32
	532480,7534584,0x83,-,1023,254,63,1023,254,63
	0,0,0x00,-,0,0,0,0,0,0
	0,0,0x00,-,0,0,0,0,0,0
	Volume(s) mounted successfully
	
	# Changing /bootfs/cmdline.txt to resize on boot...
	
	# Determining image size...
	Image Size (512 byte blocks): 8067064
	
	# Backing up image, please wait...
	Unmount of all volumes on disk9 was successful
	Fri 12 May 2023 16:35:31 MDT
	  4125876736 bytes (4126 MB, 3935 MiB) transferred 719.948s, 5731 kB/s
	8067064+0 records in
	8067064+0 records out
	4130336768 bytes transferred in 720.394257 secs (5733439 bytes/sec)
	Fri 12 May 2023 16:47:31 MDT
	
	Finished writing: myNewImageFile.img.bz2
	Now eject SD Card
