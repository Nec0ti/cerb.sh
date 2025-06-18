#!/bin/bash

run_scan() {
    mode=""
    full_port_scan=false
    mac_only=false
    live_mode=false

    # Argümanları işle
    while [[ "$1" != "" ]]; do
        case "$1" in
            --mac-only) mac_only=true ;;
            --ports) [[ "$2" == "all" ]] && full_port_scan=true; shift ;;
            --live) live_mode=true ;;
        esac
        shift
    done

    interface=$(ip route | grep default | awk '{print $5}')
    gateway=$(ip route | grep default | awk '{print $3}')
    subnet=$(ip -o -f inet addr show $interface | awk '{print $4}')

    echo -e "\n\033[1;34m🔍 CERB.NET | Gelişmiş Ağ Taraması Başlatılıyor...\033[0m"
    echo -e "🌐 Arayüz: $interface"
    echo -e "🎯 Ağ Aralığı: $subnet"
    echo -e "🚪 Varsayılan Ağ Geçidi: $gateway\n"

    mkdir -p logs/
    log_file="logs/scan_result_$(date +%s).txt"
    > "$log_file"

    function scan_range {
        echo "[*] $subnet için tarama başlatıldı..."
        for i in $(seq 1 254); do
            ip=$(echo $subnet | sed "s|0/.*|$i|")
            (
                ping -c 1 -W 1 $ip &> /dev/null && {
                    echo -e "\n💻 Cihaz Bulundu: $ip" | tee -a "$log_file"

                    if $mac_only || $full_port_scan; then
                        mac=$(arp $ip | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
                        vendor=$(curl -s "https://api.macvendors.com/$mac")
                        echo "   ↪ MAC: ${mac:-Bilinmiyor}" | tee -a "$log_file"
                        echo "   ↪ Üretici: ${vendor:-?}" | tee -a "$log_file"
                    fi

                    if ! $mac_only; then
                        echo "   ↪ Açık Portlar:" | tee -a "$log_file"
                        if $full_port_scan; then
                            for port in $(seq 1 1024); do
                                timeout 0.5 bash -c "echo >/dev/tcp/$ip/$port" 2>/dev/null &&
                                    echo "     • $port açık" | tee -a "$log_file"
                            done
                        else
                            for port in 21 22 23 80 443 445 3389; do
                                timeout 1 bash -c "echo >/dev/tcp/$ip/$port" 2>/dev/null &&
                                    echo "     • $port açık" | tee -a "$log_file"
                            done
                        fi
                    fi
                }
            ) &
        done
        wait
    }

    if $live_mode; then
        echo -e "\n🔁 Live Mode Aktif. 15 saniyede bir yeniden taranacak (CTRL+C ile çık)."
        while true; do
            scan_range
            sleep 15
        done
    else
        scan_range
        echo -e "\n✅ Tarama Tamamlandı. Kayıt: $log_file\n"
    fi
}
