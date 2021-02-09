Interoperability testing tools for [EAP-TLSv1.3](https://datatracker.ietf.org/doc/draft-ietf-emu-eap-tls13/) and corresponding [EAP types](https://datatracker.ietf.org/doc/draft-ietf-emu-tls-eap-types/).

This project supports both building a [Docker](https://docker.com/) container for development purposes and deployment over SSH to a [Debian 10](https://debian.org/) (or [Ubuntu 20.04](https://ubuntu.com/)) system.

## Related Links

 * [Using EAP-TLS with TLS 1.3 (draft-ietf-emu-eap-tls13)](https://datatracker.ietf.org/doc/draft-ietf-emu-eap-tls13/)
 * [TLS-based EAP types and TLS 1.3 (draft-ietf-emu-tls-eap-types)](https://datatracker.ietf.org/doc/draft-ietf-emu-tls-eap-types/)

# Preflight

This project should work on both Linux, macOS and [Windows 10 where WSL is installed](https://docs.microsoft.com/en-us/windows/wsl/install-win10).

You will require installed (available through `apt-get install ...` and `yum install ...`):

  * `git`
  * `make`

Check out a copy of the project:

    git clone git@gitlab.com:coremem/networkradius/interop-eap-tls13.git
    cd interop-eap-tls13

# Development

If you have [Docker](https://docker.com/) installed then you can run the following to create a suitable local development environment:

    make dev PORT=1812

**N.B.** `PORT` sets the port number that RADIUS authentication is exposed on your workstation, it defaults to `1812` and can be left out

Some information about the environment:

 * login details for the container is `root` with no password
 * shutdown the container by typing `halt` from within it or use `docker stop interop-eap-tls13`
 * your local workstation will have the following ports exposed:
     * **`[PORT]/{udp,tcp}` (default: `PORT=1812`):** RADIUS authentication
 * environment makes use of a number of read only bind mounts into the container
     * they are as described:
         * [`services`](services): `services` configuration (including `freeradius`)
         * [`eapol_test`](eapol_test): `eapol_test` configuration files
     * changes to these folders will be immediately seen inside the docker container. This means you should not need to edit files in the container and remember to copy them back to your project, and after updating `services/freeradius/...` you can restart `freeradius` (`systemctl restart freeradius` or `freeradius -X`) to reason about those changes

## Deployment to a Server/VM

...

# Usage

The project is already configured to test TLSv1.3 without the user having to edit any configuration files.

## Testing

The project comes with a number of `eapol_test` configuration files for you to use by running:

    cd /opt/networkradius/interop-eap-tls13
    eapol_test -s testing123 -c eapol_test/eapol_test.tls.conf

The tests in the `eapol_test` directory are named after the EAP methods they use and the suite covers:

 * EAP-TLS
 * EAP-TTLS/{PAP,MSCHAPv2,EAP-MSCHAPv2,EAP-TLS}
 * PEAP/{MSCHAPv2,EAP-TLS,EAP-TLS+MSCHAPv2}

### TLS Certificates

If you are running `eapol_test` from your workstation (rather than inside a Docker container or on a server) you will need to copy the certificates into the project to allow authentication to work.

If you are using Docker, use:

    docker cp interop-eap-tls13:/etc/freeradius/certs .

If you are using a server, try:

    rsync -rv --rsync-path 'sudo rsync' server.example.com:/etc/freeradius/certs .

### TLS Configuration

#### Version

To have `eapol_test` use TLSv1.2 or earlier edit the configuration file and change `tls_disable_tlsv1_[0-3]=1` appropriately.

If you want to force FreeRADIUS to *only* accept something later than TLSv1.0 you can edit `services/freeradius/mods-available/eap-test` and to reflect in the `tls-config` section your choosing:

    tls_min_version = "1.0"
    tls_max_version = "1.3"

#### Using TLS Close Notify or Commitment Message

The latest EAP-TLSv1.3 draft uses [TLS Close Notify](https://tools.ietf.org/html/draft-ietf-emu-eap-tls13-14#section-2.1.4) to signal the end of the handshake whilst earlier drafts used a [Commitment Message](https://tools.ietf.org/html/draft-ietf-emu-eap-tls13-13#section-2.1.4).

Though FreeRADIUS defaults to using TLS Close Notify this project configures the Commitment Message code path as the patches to [`hostap`/`wpa_supplicant`/`eapol_test`](https://w1.fi/) support only this.

To toggle FreeRADIUS to use TLS Close Notify, edit `services/freeradius/mods-available/eap-test` to reflect in the `tls-config` section:

    tls13_send_zero = no

Now restart FreeRADIUS in the usual manner using:

    systemctl restart freeradius

## Debugging

To put FreeRADIUS into debugging mode, use the following:

    systemctl stop freeradius
    freeradius -X | tee /tmp/debug

The debug output will be sent to both your terminal and logged to the file `/tmp/debug`.

## Custom Build

### FreeRADIUS

...

### hostap

...
