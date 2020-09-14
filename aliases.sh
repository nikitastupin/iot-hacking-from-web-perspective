transparent-proxy() {
  usage() {
    echo "usage: transparent-proxy { <file> | disable }" >&2
    echo "    { <file> | disable }  Consumes <file> with pf rules, enables pf and IP forwarding, disables ICMP redirect if file is specified. If 'disabled' is specified disables pf and IP forwarding." >&2
  }

  if [[ $# -ne 1 ]]; then
    usage
    return 1
  fi

  SUDOERS_CONF="/etc/sudoers.d/mitmproxy"

  # https://docs.mitmproxy.org/stable/howto-transparent/#macos
  if [[ -f "$1" ]]; then
    ENABLE_FORWARDING="sudo sysctl net.inet.ip.forwarding=1"
    /bin/bash -c "$ENABLE_FORWARDING"

    DISABLE_ICMP_REDIRECT="sudo sysctl net.inet.ip.redirect=0"
    /bin/bash -c "$DISABLE_ICMP_REDIRECT"

    # e.g. 'rdr pass on en0 inet proto tcp to any port {80, 443} -> 127.0.0.1 port 8080'
    PF_CONF="$1"
    LOAD_PF_RULES="sudo pfctl -f ${PF_CONF}"
    /bin/bash -c "$LOAD_PF_RULES"

    ENABLE_PF="sudo pfctl -e"
    /bin/bash -c "$ENABLE_PF"

    echo "\$ echo 'ALL ALL=NOPASSWD: /sbin/pfctl -s state' | sudo tee ${SUDOERS_CONF}"
    echo "ALL ALL=NOPASSWD: /sbin/pfctl -s state" | sudo tee "${SUDOERS_CONF}"

    echo -e "\nResulting pf NAT rules:"
    sudo pfctl -s nat
  elif [[ "$1" == "disable" ]]; then
    DISABLE_FORWARDING="sudo sysctl net.inet.ip.forwarding=0"
    /bin/bash -c "$DISABLE_FORWARDING"

    ENABLE_ICMP_REDIRECT="sudo sysctl net.inet.ip.redirect=1"
    /bin/bash -c "$ENABLE_ICMP_REDIRECT"

    FLUSH_NAT="sudo pfctl -F nat"
    /bin/bash -c "$FLUSH_NAT"

    DISABLE_PF="sudo pfctl -d"
    /bin/bash -c "$DISABLE_PF"

    RM_SUDOERS_CONF="sudo rm ${SUDOERS_CONF}"
    echo "$RM_SUDOERS_CONF"
    /bin/bash -c "$RM_SUDOERS_CONF"
  else
    usage
    return 2
  fi
}

killssl() {
  if [[ $# -ne 1 ]]; then
    echo "Please specify a package you want to run and MitM" 1>&2
    return 1
  fi

  if ! adb shell pm list packages | grep -q "$1"; then
    echo "Package '$1' doesn't exists on your Android" 1>&2
    return 2
  fi

  if ! adb shell ps | grep -q frida-server; then
    adb shell 'su -c nohup /data/local/tmp/frida-server &'
  fi

  # https://gist.github.com/cubehouse/56797147b5cb22768b500f25d3888a22
  PINNING_JS="/full/path/to/pinning.js"

  frida -U -l "$PINNING_JS" --no-pause -f "$1"
}
