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

...

## Testing

Edit `/tmp/eapol_test.conf` with your credentials and then run:

    eapol_test -s testing123 -c /opt/networkradius/interop-eap-tls13/eapol_test/eapol_test.tls.conf

The tests in the `/opt/networkradius/interop-eap-tls13/eapol_test` directory include:

 * EAP-TLS
 * EAP-TTLS/{PAP,MSCHAPv2,EAP-MSCHAPv2,EAP-TLS}
 * PEAP/{MSCHAPv2,EAP-TLS,EAP-TLS+MSCHAPv2}

To use TLSv1.2 or earlier edit the configuration file and change `tls_disable_tlsv1_X=1` appropriately.

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
