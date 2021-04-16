#!/bin/sh

set -eu

DISK=${DISK:-hda.qcow2}
[ -f "$DISK" ] || qemu-img create -f qcow2 "$DISK" 40G

[ -f virtio-win.iso ] || curl -O -J -L -f --compressed https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso

# sudo groupadd -r hugetlbfs
# sudo sysctl -w vm.hugetlb_shm_group=$(getent group | grep hugetlbfs | cut -d: -f3)
# sudo mount -t hugetlbfs /dev/hugepages hugetlbfs -o remount,pagesize=2M,mode=01770,gid=$(getent group | grep hugetlbfs | cut -d: -f3)
HUGEPAGES=${HUGEPAGES:-/dev/hugepages}
[ $(/sbin/sysctl -n vm.nr_hugepages) -ne 0 -a -w "$HUGEPAGES" ] || HUGEPAGES=

exec qemu-system-x86_64 \
	-nodefaults -serial none -parallel none \
	-machine q35,accel=kvm:tcg \
	-cpu host,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time \
	-smp cpus=4,cores=2,threads=2 \
	-m 4G,slots=3,maxmem=16G \
	${HUGEPAGES:+-mem-path "$HUGEPAGES/qemu"} \
	-vga qxl -device virtio-serial-pci -spice port=5930,disable-ticketing -device virtserialport,chardev=spicechannel0,name=com.redhat.spice.0 -chardev spicevmc,id=spicechannel0,name=vdagent \
	-device virtio-balloon \
	-device ahci,id=ahci \
	-drive if=virtio,file="$DISK",format=qcow2 \
	${ISO:+-drive if=none,id=cdrom0,media=cdrom,file="$ISO",readonly=on} \
	${ISO:+-device ide-cd,drive=cdrom0,bus=ahci.1} \
	${ISO:+-drive if=none,id=cdrom1,media=cdrom,file=virtio-win.iso,readonly=on} \
	${ISO:+-device ide-cd,drive=cdrom1,bus=ahci.2} \
	-boot order=c${ISO:+,once=d} \
	-device qemu-xhci \
	-device usb-tablet -device usb-kbd \
	-rtc base=localtime,clock=host \
	-netdev user,id=eth0 -device virtio-net-pci,netdev=eth0 \
	-netdev l2tpv3,id=eth1,src=127.0.0.1,dst=127.0.0.1,udp,srcport=0,dstport=1701,txsession=0xffffffff,rxsession=0xffffffff,counter -device virtio-net-pci,netdev=eth1 \
	-monitor stdio
