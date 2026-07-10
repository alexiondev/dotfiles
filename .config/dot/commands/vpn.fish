function _dot_vpn_usage
    echo "usage: dot vpn <command>

Commands:
  up      bring the UDM-PRO-Laptop WireGuard connection up
  down    bring the UDM-PRO-Laptop WireGuard connection down
  help    show this message"
end

function _dot_vpn
    if test "$argv[1]" = help
        _dot_vpn_usage
        return 0
    end

    set -l connection UDM-PRO-Laptop

    switch "$argv[1]"
        case up
            nmcli connection up $connection
            return $status
        case down
            nmcli connection down $connection
            return $status
        case '*'
            _dot_vpn_usage
            return 1
    end
end
