Interoperability testing tools for [EAP-TLSv1.3](https://datatracker.ietf.org/doc/draft-ietf-emu-eap-tls13/) and corresponding [EAP types](https://datatracker.ietf.org/doc/draft-ietf-emu-tls-eap-types/).

This project supports both building a [Docker](https://docker.com/) container for development purposes and deployment over SSH to a [Debian 10](https://debian.org/) (or [Ubuntu 20.04](https://ubuntu.com/)) system.

## Related Links

 * [Using EAP-TLS with TLS 1.3 (draft-ietf-emu-eap-tls13)](https://datatracker.ietf.org/doc/draft-ietf-emu-eap-tls13/)
 * [TLS-based EAP types and TLS 1.3 (draft-ietf-emu-tls-eap-types)](https://datatracker.ietf.org/doc/draft-ietf-emu-tls-eap-types/)

# Preflight

You will require:

  * `git`
  * `make`

Check out a copy of the project:

    git clone git@gitlab.com:coremem/networkradius/interop-eap-tls13.git
    cd interop-eap-tls13

# Development

If you have [Docker](https://docker.com/) installed then you can run the following to create a suitable local development environment:

    make dev

Some information about the environment:

 * login details for the container is `root` with no password
 * your local workstation will have the following ports opened
     * **`1812/{udp,tcp}`:** RADIUS authentication
 * environment makes use of a number of read only bind mounts into the container
     * they are as described:
         * [`freeradius`](freeradius): `freeradius` configuration
     * changes to these folders will be immediately seen inside the docker container. This means you should not need to edit files in the container and remember to copy them back to your project, and after updating `freeradius`/... you can restart `freeradius` (`systemctl restartfreeradius` or `freeradius -X`) to reason about those changes

## Testing

Edit `/tmp/eapol_test.conf` with your credentials and then run:

    eapol_test -s testing123 -c /opt/networkradius/interop-eap-tls13/eapol_test/eapol_test.tls.conf

The tests in the `/opt/networkradius/interop-eap-tls13/eapol_test` directory include:

 * EAP-TLS
 * EAP-TTLS/{PAP,MSCHAPv2,EAP-MSCHAPv2,EAP-TLS}
 * PEAP/{MSCHAPv2,EAP-TLS,EAP-TLS+MSCHAPv2}

To have `eapol_test` use TLSv1.2 or earlier edit the configuration file and change `tls_disable_tlsv1_[0-3]=1` appropriately.

If you want to force FreeRADIUS to *only* accept something later than TLSv1.0 you can edit `/opt/networkradius/interop-eap-tls13/services/freeradius/mods-available/eap-test` and to reflect in the `tls-config` section your choosing:

    tls_min_version = "1.0"
    tls_max_version = "1.3"

## Using TLS Close Notify or Commitment Message

The latest EAP-TLSv1.3 draft uses [TLS Close Notify](https://tools.ietf.org/html/draft-ietf-emu-eap-tls13-14#section-2.1.4) to signal the end of the handshake whilst earlier drafts used a [Commitment Message](https://tools.ietf.org/html/draft-ietf-emu-eap-tls13-13#section-2.1.4).

Though FreeRADIUS defaults to using TLS Close Notify this project configures the Commitment Message codepath as the patches to [`hostap`/`wpa_supplicant`/`eapol_test`](https://w1.fi/) support only this.

To toggle FreeRADIUS to use TLS Close Notify, edit `/opt/networkradius/interop-eap-tls13/services/freeradius/mods-available/eap-test` to reflect in the `tls-config` section:

    tls13_send_zero = no

Now restart FreeRADIUS in the usual manner using:

    systemctl restart freeradius

## Debugging

To put FreeRADIUS into debugging mode, use the following:

    systemctl stop freeradius
    freeradius -X | tee /tmp/debug

The debug output will be sent to both your terminal and logged to the file `/tmp/debug`.

# Deploy

...
