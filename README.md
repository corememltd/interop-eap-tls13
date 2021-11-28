Interoperability testing tools for [EAP-TLSv1.3](https://datatracker.ietf.org/doc/draft-ietf-emu-eap-tls13/) and corresponding [EAP types](https://datatracker.ietf.org/doc/draft-ietf-emu-tls-eap-types/).

This project supports both building and running a [Docker](https://docker.com/) container for development purposes as well as deployment over SSH to a [Debian 'bullseye' 11](https://debian.org/) (or [Ubuntu 'focal' 20.04](https://ubuntu.com/)) system.

## Related Links

 * [Using EAP-TLS with TLS 1.3 (draft-ietf-emu-eap-tls13)](https://datatracker.ietf.org/doc/draft-ietf-emu-eap-tls13/)
     * The current (revision 14 at time of writing) EAP-TLSv1.3 draft uses [TLS Close Notify](https://tools.ietf.org/html/draft-ietf-emu-eap-tls13-14#section-2.1.4) to signal the end of the handshake whilst earlier drafts used a [Commitment Message](https://tools.ietf.org/html/draft-ietf-emu-eap-tls13-13#section-2.1.4)
     * FreeRADIUS, Microsoft Windows 11 and hostapd all only implement the Commitment Message (pre-rev14) draft
 * [TLS-based EAP types and TLS 1.3 (draft-ietf-emu-tls-eap-types)](https://datatracker.ietf.org/doc/draft-ietf-emu-tls-eap-types/)

# Quick Start with Docker

If you have [Docker](https://docker.com/) installed then you can run the following to create a suitable local development environment:

    docker pull registry.gitlab.com/coremem/networkradius/interop-eap-tls13:latest
    docker tag registry.gitlab.com/coremem/networkradius/interop-eap-tls13:latest networkradius/interop-eap-tls13:latest
    docker run -it --rm \
      --name interop-eap-tls13 \
      -e container=docker \
      --publish=${PORT:-1812}:1812/udp --publish=${PORT:-1812}:1812/tcp \
      --publish=${L2TP:-1701}:1701/udp \
      --tmpfs /run \
      --cgroupns=host \
      -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
      --ulimit memlock=$((128 * 1024)) \
      --security-opt apparmor=unconfined \
      --cap-add SYS_ADMIN --cap-add NET_ADMIN --cap-add SYS_PTRACE \
      --stop-signal SIGPWR \
      networkradius/interop-eap-tls13:latest

**N.B.** to publish the RADIUS service to an alternative port you can export `PORT` (default: `1812`) before running `docker run ...`

You can also open one or more terminals into the running environment using:

    docker exec -it interop-eap-tls13 /bin/bash

Some information about the environment:

 * login details for the container is `root` with no password
 * there are no text editors on the system, to install one use `apt-get update && apt-get install ...`
 * shutdown the container by typing `halt` from within it or use `docker stop interop-eap-tls13`
 * your local workstation will have the following ports exposed:
     * **`[PORT]/{udp,tcp}` (default: `PORT=1812`):** RADIUS authentication
         * globally listens and accepts any client using the shared secret `testing123`
     * **`[L2TP]/udp` (default: `L2TP=1701`):** L2TP
         * useful for testing wired 802.1X from a VM that supports L2TP backed Ethernet interfaces such as QEMU; `hostapd` runs as the authenticator and a DHCP server runs on the interface so an IP can be assigned (no default gateway)
         * UDP source port can be anything
         * requires the local/peer tunnel ID set to `1` and the session ID (both RX and TX) to `0xffffffff` (`4294967295`)
         * make sure the guest is configured for an MTU of 1446 bytes
             * Linux: `ip link set dev eth1 mtu 1446`
             * Microsoft Windows 11: `netsh interface ipv4 set subinterface "Ethernet 2" mtu=1446 store=persistent`
         * [QEMU example](https://qemu-project.gitlab.io/qemu/system/invocation.html) (change *only* `src` and `dst`): `-netdev l2tpv3,id=eth1,src=192.0.2.1,dst=192.0.2.2,udp,srcport=0,dstport=1701,txsession=0xffffffff,counter -device virtio-net-pci,netdev=eth1`

# Usage

The project is already configured to test TLSv1.3 without the user needing to edit any configuration files.

**N.B.** the instructions below assume you are running commands from on the target system (container, VM or server)

## Testing

The project comes with a number of `eapol_test` configuration files for you to use by running:

    cd /opt/networkradius/interop-eap-tls13
    eapol_test -s testing123 -a 127.0.0.1 -p 1812 -c eapol_test/eapol_test.tls.conf

**N.B.** add `-r 1` as a argument to `eapol_test` to test resumption

The tests in the `eapol_test` directory are named after the EAP methods they use and the suite covers:

 * EAP-TLS
 * EAP-TTLS/{PAP,MSCHAPv2,EAP-MSCHAPv2,EAP-TLS}
 * PEAP/{MSCHAPv2,EAP-TLS,EAP-TLS+MSCHAPv2}

**N.B.** if you are using your own supplicant, for the username/password flows the credentials are `bob`/`bob`

You can also run the EAP-TLS unit tests which utilise `eapol_test` that come with FreeRADIUS:

    cd /usr/src/freeradius-server
    make test

### Debugging

To run FreeRADIUS in debugging mode, use the following:

    systemctl stop freeradius
    freeradius -X | tee /tmp/debug

The debug output will be sent to both your terminal and logged to the file `/tmp/debug`.

### TLS Certificates

If you wish to run `eapol_test` (or another EAP-TLS supplicant) not on the target system (ie. not inside the Docker container or server) you will need to copy the certificates into the project to allow authentication to work.

If you are using Docker, use:

    docker cp interop-eap-tls13:/etc/freeradius/certs .

If you are using a server, try:

    rsync -rv --rsync-path 'sudo rsync' server.example.com:/etc/freeradius/certs .

From that directory, import `ca.{pem,der}` and `client.{{pem,key},p12}` (password '`whatever`') onto your system; Windows users should make sure to import the CA into the 'Trusted Root Certificate Authorities' and not use the automatic option. Once done you should b able to validate the hostname CN against `Example Server Certificate`.

### TLS Configuration

#### Version

To have `eapol_test` use TLSv1.2 or earlier edit the configuration file and change `tls_disable_tlsv1_[0-3]=1` appropriately.

If you want to force FreeRADIUS to *only* accept something later than TLSv1.0 you can edit `services/freeradius/mods-available/eap-test` and to reflect in the `tls-config` section your choosing:

    tls_min_version = "1.0"
    tls_max_version = "1.3"

##### OpenSSL

Newer operating systems (eg. Debian 'buster' 10, Ubuntu 'focal' 20.04, ...) globally disable use of anything earlier than TLSv1.2 via `/etc/ssl/openssl.cnf` which can be re-enabled when needed by editing the configuration files in the `eapol_test` directory and uncommenting the following line:

    openssl_ciphers="DEFAULT@SECLEVEL=1"

#### TLS Decoding

For this to work you will require [Wireshark](https://www.wireshark.org/) to be installed on your workstation, below details the walk-through from the Wireshark Wiki topic on [TLS Decryption](https://wiki.wireshark.org/TLS). When this process works you should be able to reconstruct similar screenshots to below (examples included before you try creating your own):

 * draft 13 (commitment message):
     * [screenshot](./wireshark-examples/screenshot.png)
     * [`dump.pcap`](./wireshark-examples/dump.pcap)
     * [`sslkey.log`](./wireshark-examples/sslkey.log)
 * Windows 11
     * PEAP
         * EAP-MSCHAPv2
             * [`debug`](./wireshark-examples/win11/peap-eap-mschapv2/debug)
             * [`dump.pcap`](./wireshark-examples/win11/peap-eap-mschapv2/dump.pcap)
             * [`sslkey.log`](./wireshark-examples/win11/peap-eap-mschapv2/sslkey.log)
         * EAP-TLS
             * [`debug`](./wireshark-examples/win11/peap-eap-tls/debug)
             * [`dump.pcap`](./wireshark-examples/win11/peap-eap-tls/dump.pcap)
             * [`sslkey.log`](./wireshark-examples/win11/peap-eap-tls/sslkey.log)
     * EAP-TTLS - requires [patches](https://github.com/FreeRADIUS/freeradius-server/compare/v3.0.x...jimdigriz:eaptls13)
         * PAP
             * [`debug`](./wireshark-examples/win11/ttls-pap/debug)
             * [`dump.pcap`](./wireshark-examples/win11/ttls-pap/dump.pcap)
             * [`sslkey.log`](./wireshark-examples/win11/ttls-pap/sslkey.log)
         * CHAP
             * [`debug`](./wireshark-examples/win11/ttls-chap/debug)
             * [`dump.pcap`](./wireshark-examples/win11/ttls-chap/dump.pcap)
             * [`sslkey.log`](./wireshark-examples/win11/ttls-chap/sslkey.log)
         * MSCHAP
             * [`debug`](./wireshark-examples/win11/ttls-mschap/debug)
             * [`dump.pcap`](./wireshark-examples/win11/ttls-mschap/dump.pcap)
             * [`sslkey.log`](./wireshark-examples/win11/ttls-mschap/sslkey.log)
         * EAP-TLS
             * [`debug`](./wireshark-examples/win11/ttls-eap-tls/debug)
             * [`dump.pcap`](./wireshark-examples/win11/ttls-eap-tls/dump.pcap)
             * [`sslkey.log`](./wireshark-examples/win11/ttls-eap-tls/sslkey.log)
         * EAP-MSCHAPv2
             * [`debug`](./wireshark-examples/win11/ttls-eap-mschapv2/debug)
             * [`dump.pcap`](./wireshark-examples/win11/ttls-eap-mschapv2/dump.pcap)
             * [`sslkey.log`](./wireshark-examples/win11/ttls-eap-mschapv2/sslkey.log)

**N.B.** if you do not see the 'Decrypted SSL' tab at the bottom, you may not have the correct SSL key log paired with its PCAP file

Inside the container, run in one terminal `tcpdump` set to capture all RADIUS authentication traffic:

    tcpdump -n -p -i lo -w - -U port 1812 | tee /tmp/dump.pcap | tcpdump -n -v -r -

**N.B.** alternatively you run this step on the host end against the `docker0` network interface

    systemctl stop freeradius
    rm -f /tmp/sslkey.log
    env SSLKEYLOGFILE=/tmp/sslkey.log freeradius -X | tee /tmp/debug

**N.B.** you should delete `/tmp/sslkey.log` between subsequent runs

Now run some authentication requests with `eapol_test` in yet another console terminal as shown earlier. Once complete, terminate (using `Ctrl-C`) the FreeRADIUS and copy `/tmp/dump.pcap` and `/tmp/sslkey.log` to your host system where you will be running Wireshark, you can do this by running from the host end:

    docker cp interop-eap-tls13:/tmp/dump.pcap .
    docker cp interop-eap-tls13:/tmp/sslkey.log .

On your host:

 1. open the 'Edit' menu and select 'Preferences'
 1. open 'Protocols' and select 'TLS' (older versions call it 'SSL') from the list
     * add '(Pre)-Master-Secret log' by browsing and selecting `sslkey.log`
     * click on 'OK'
 1. close the preferences window
 1. open `dump.pcap` in Wireshark

### Microsoft Windows 11

To use Windows 11 Insider Preview (Dev Channel, tested with build 22499, upgraded to 22504.1000) you will need QEMU (tested with version 5.2.0) and to have built and started a [software based TPM](https://github.com/stefanberger/swtpm):

    docker build -t swtpm swtpm
    docker run -v "$PWD/swtpm/state:/run/swtpm" swtpm

Once running, you can use the enclosed script:

    env ISO=Windows11_InsiderPreview_Client_x64_en-gb_22499.iso sh -x qemu-win11.sh

Connect to the VM using the [Spice client](https://www.spice-space.org/):

    spicy -h 127.0.0.1 -p 5930

The script will also fetch the [virtio-win drivers](https://github.com/virtio-win/virtio-win-pkg-scripts) and add a CD mount in the VM so drivers are available for the VirtIO devices as well as the including the Spice guest agent.

**N.B.** when you configure the network interface, make sure you use the old 'Control Panel' interface as it will reflect your 802.1X configuration correctly

From the [QEMU monitor](https://qemu.readthedocs.io/en/latest/system/monitor.html), you can type the following to toggle the network link state:

    set_link eth1 off
    set_link eth1 on

It is recommended you turn off system suspend on idle on the VM otherwise you may have to remember to type `system_wakeup` into the QEMU monitor to kick it back into life regularly.

#### EAP-TTLS and PEAP

If you have contacts on the Microsoft EAP team, they might be able to provide access to `EnableFeatureTool.exe` (tested version has MD5 matching `3c834de11f33fd7b3c5c6585f08d727f`) which you can use to enable these methods.

**N.B.** when using PEAP make sure you have 'Disconnect if server does not present cryptobinding TLV' *unchecked* as FreeRADIUS does not currently support this

#### Bugs

These are observed bugs in Windows 11:

 1. even if you ask *not* to verify against a CA or server name, you still must configure it all:
     * set 'Connect to these servers' to `Example Server Certificate`
     * set 'Trusted Root Certificate Authorities' to `Example Certificate Authority`
 1. due to a (known to MS) bug in wired 802.1X, if you see no traffic going to the RADIUS server, use the old 'Control Panel' interface to 'Disable' and re-enable the interface to clear it out from a latched/wedged state
 1. the 'Sign in' button in the new UI may not appear or stop functioning resulting in no EAP communication
     * a workaround is to close completely the new UI page and let the prompt re-open it for you
     * if that fails, make sure you have checked 'Fall-back to unauthorized network access', otherwise you will never see the 'Sign in' button or popup window to enter credentials
 1. for EAP-TTLS when the new UI asks you to confirm the presented server certificate clicking on 'Show certificate details' does no more than jiggle the popup. The workaround is to set it up to avoid any certificate related popups (request for the user credential popup works fine though)
     * create a working PEAP profile and authenticate with it
     * export this PEAP profile with:

           netsh lan export profile folder=path_to_folder

     * open the profile and find *all* the values (even if you have selected only one, there seem to be two in there regardless!) used for `TrustedRootCA` in the XML and make a note of it
     * create a EAP-TTLS profile as usual and then export it like the PEAP one
     * open the profile and replace the value used for `TrustedRootCAHash` (`TrustedRootCA` is not used here you need to use `Hash`) in the XML with the one from the PEAP profile
     * import the updated profile with:

           netsh lan add profile interface="Ethernet 2" filename="EAP_TTLS_profile_file_path"

# Development

If you wish to build the project locally, the rest of this document describes that process.

Once built (or deployed) the target system (container, server or VM) will locate the project at `/opt/networkradius/interop-eap-tls13` and use symlinks to plumb the various configuration files into place.

The `setup` shell script of the project contains the machinery to bring up the project on a bare system; [Packer](https://packer.io/) is used to orchestrate the running of this script but you should not need to [understand it to use or develop this project](https://packer.io/docs).

## Preflight

This project should work on both Linux, macOS and [Windows 10 where WSL is installed](https://docs.microsoft.com/en-us/windows/wsl/install-win10).

You will require installed (available through `apt-get install ...` and `yum install ...`):

  * `ca-certificates`
  * `curl`
  * `git`
  * `make`
  * `unzip`

Check out a copy of the project:

    git clone https://gitlab.com/coremem/networkradius/interop-eap-tls13.git
    cd interop-eap-tls13

## Targets

### Docker

Similar to the [quick start instructions](#quick-start-with-docker), but the following will instead build and launch the Docker image from scratch:

    make dev PORT=1812 FROM=debian:bullseye-slim BRANCH=v3.0.x TAG=release_3_0_25

Where the configuration values are described as:

 * **`PORT` (default: `1812`):** sets the port number that RADIUS authentication is exposed on your workstation
 * **`FROM` (default: [`debian:bullseye-slim`](https://hub.docker.com/_/debian/)):** sets the base Docker image to build on
     * [`ubuntu:focal`](https://hub.docker.com/_/ubuntu/) is also known to work
 * **`FREERADIUS_REPO`:** if you want to work on a local tree, set this to the path of your local FreeRADIUS source tree and run the following inside the container to build and apply (do not install the 'config' Debian package!):

           make -C /usr/src/freeradius-server deb
           dpkg -i /usr/src/{freeradius,libfreeradius3}_*_amd64.deb

 * **`REPO` (default: `https://github.com/FreeRADIUS/freeradius-server.git`):** sets the repo source of FreeRADIUS to use
 * **`BRANCH` (default: `v3.0.x`):** sets the branch of FreeRADIUS to use
 * **`TAG` (default: `release_3_0_25`):** sets the tag of FreeRADIUS to use
     * when using a custom branch where no tag is avaliable you should use `HEAD` here

Additional information about the environment:

 * environment makes use of a number of read only bind mounts into the container
     * they are as described:
         * [`services`](services): `services` configuration (including `freeradius`)
         * [`eapol_test`](eapol_test): `eapol_test` configuration files
     * changes to these folders will be immediately seen inside the docker container. This means you should not need to edit files in the container and remember to copy them back to your project, and after updating `services/freeradius/...` you can restart `freeradius` (`systemctl restart freeradius` or `freeradius -X`) to reason about those changes

### Server/VM via-SSH

To deploy to a VM (or bare metal) server instead you first need to prepare it so that you can:

 * SSH into the server [using SSH public key authentication (no password) via an agent](https://www.cyberciti.biz/faq/how-to-use-ssh-agent-for-authentication-on-linux-unix/)
 * run `sudo -s` [without being prompted for your password](https://www.cyberciti.biz/faq/linux-unix-running-sudo-command-without-a-password/)

If you have it configured correctly, you should be able to run the following and it will tell you are `root` without prompting for your password:

    $ ssh 192.0.2.100 sudo id
    uid=0(root) gid=0(root) groups=0(root)

Once ready, run the following:

    make deploy SSH_HOST=192.0.2.100 SSH_USER=username

**N.B.** `SSH_HOST` is required and `SSH_USER` defaults to your username (provided via the environment variable `$USER`)

**N.B.** it is safe to rerun the deploy against a VM server you have already deployed to
