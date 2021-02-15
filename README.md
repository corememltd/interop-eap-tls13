Interoperability testing tools for [EAP-TLSv1.3](https://datatracker.ietf.org/doc/draft-ietf-emu-eap-tls13/) and corresponding [EAP types](https://datatracker.ietf.org/doc/draft-ietf-emu-tls-eap-types/).

This project supports both building and running a [Docker](https://docker.com/) container for development purposes as well as deployment over SSH to a [Debian 'buster' 10](https://debian.org/) (or [Ubuntu 'focal' 20.04](https://ubuntu.com/)) system.

## Related Links

 * [Using EAP-TLS with TLS 1.3 (draft-ietf-emu-eap-tls13)](https://datatracker.ietf.org/doc/draft-ietf-emu-eap-tls13/)
 * [TLS-based EAP types and TLS 1.3 (draft-ietf-emu-tls-eap-types)](https://datatracker.ietf.org/doc/draft-ietf-emu-tls-eap-types/)

# Quick Start with Docker

If you have [Docker](https://docker.com/) installed then you can run the following to create a suitable local development environment:

    docker pull registry.gitlab.com/coremem/networkradius/interop-eap-tls13:latest
    docker tag registry.gitlab.com/coremem/networkradius/interop-eap-tls13:latest networkradius/interop-eap-tls13:latest
    docker run -it --rm \
      --name interop-eap-tls13 \
      -e container=docker \
      --publish=${PORT:-1812}:1812/udp --publish=${PORT:-1812}:1812/tcp \
      --tmpfs /run \
      -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
      --ulimit memlock=$((128 * 1024)) \
      --security-opt apparmor=unconfined \
      --cap-add SYS_ADMIN --cap-add NET_ADMIN --cap-add SYS_PTRACE \
      --stop-signal SIGPWR \
      networkradius/interop-eap-tls13:latest

**N.B.** to publish the RADIUS service to an alternative port you can export `PORT` (default: `1812`) before running `docker run ...`

Some information about the environment:

 * login details for the container is `root` with no password
 * shutdown the container by typing `halt` from within it or use `docker stop interop-eap-tls13`
 * your local workstation will have the following ports exposed:
     * **`[PORT]/{udp,tcp}` (default: `PORT=1812`):** RADIUS authentication
         * globally listens and accepts any client using the shared secret `testing123`

# Usage

The project is already configured to test TLSv1.3 without the user needing to edit any configuration files.

**N.B.** the instructions below assume you are running commands from on the target system (container, VM or server)

## Testing

The project comes with a number of `eapol_test` configuration files for you to use by running:

    cd /opt/networkradius/interop-eap-tls13
    eapol_test -s testing123 -a 127.0.0.1 -p 1812 -c eapol_test/eapol_test.tls.conf

The tests in the `eapol_test` directory are named after the EAP methods they use and the suite covers:

 * EAP-TLS
 * EAP-TTLS/{PAP,MSCHAPv2,EAP-MSCHAPv2,EAP-TLS}
 * PEAP/{MSCHAPv2,EAP-TLS,EAP-TLS+MSCHAPv2}

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

### TLS Configuration

#### Using TLS Close Notify or Commitment Message

The current (revision 14 at time of writing) EAP-TLSv1.3 draft uses [TLS Close Notify](https://tools.ietf.org/html/draft-ietf-emu-eap-tls13-14#section-2.1.4) to signal the end of the handshake whilst earlier drafts used a [Commitment Message](https://tools.ietf.org/html/draft-ietf-emu-eap-tls13-13#section-2.1.4).

Though FreeRADIUS defaults to using TLS Close Notify this project configures the Commitment Message code path as the patches to [`hostap`/`wpa_supplicant`/`eapol_test`](https://w1.fi/) support only this.

To toggle FreeRADIUS to use TLS Close Notify, edit `services/freeradius/mods-available/eap-test` to reflect in the `tls-config` section:

    tls13_send_zero = no

Now restart FreeRADIUS in the usual manner using:

    systemctl restart freeradius

**N.B.** remember by doing this `eapol_test` will no longer work

#### Version

To have `eapol_test` use TLSv1.2 or earlier edit the configuration file and change `tls_disable_tlsv1_[0-3]=1` appropriately.

If you want to force FreeRADIUS to *only* accept something later than TLSv1.0 you can edit `services/freeradius/mods-available/eap-test` and to reflect in the `tls-config` section your choosing:

    tls_min_version = "1.0"
    tls_max_version = "1.3"

##### OpenSSL

Newer operating systems (eg. Ubuntu 'focal' 20.04) globally disable use of anything earlier than TLSv1.2 which can be re-enabled by editing `/etc/ssl/openssl.cnf` and have it top and tailed with:

    openssl_conf = default_conf
    
    <<<existing contents of openssl.cnf>>>
    
    [default_conf]
    ssl_conf = ssl_sect
    
    [ssl_sect]
    system_default = system_default_sect
    
    [system_default_sect]
    CipherString = DEFAULT@SECLEVEL=1

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

    make dev PORT=1812 FROM=debian:buster-slim

Where the configuration values are described as:

 * **`PORT` (default: `1812`):** sets the port number that RADIUS authentication is exposed on your workstation
 * **`FROM` (default: [`debian:buster-slim`](https://hub.docker.com/_/debian/)):** sets the base Docker image to build on
     * [`ubuntu:focal`](https://hub.docker.com/_/ubuntu/) is also known to work

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

## Custom Build

### FreeRADIUS

...

### hostap

...
