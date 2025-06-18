#!/bin/bash

run_scan() {
    echo -e "\n\033[1;34m🔍 CERB.NET | Gelişmiş Ağ Taraması Başlıyor...\033[0m\n"

    interface=$(ip route | grep default | awk '{print $5}')
    gateway=$(ip route | grep default | awk '{print $3}')
    subnet=$(ip -o -f inet addr show $interface | awk '{print $4}')

    echo -e "🌐 Arayüz: $interface"
    echo -e "🎯 Ağ Aralığı: $subnet"
    echo -e "🚪 Varsayılan Ağ Geçidi: $gateway\n"

    echo "[*] Aktif cihazlar taranıyor..."
    mkdir -p logs/
    > logs/scan_result.txt

    # Ağdaki cihazları bul (arp-scan yerine ping tabanlı)
    for ip in $(seq 1 254); do
        target=$(echo $subnet | sed "s|0/.*|$ip|")
        (ping -c 1 -W 1 $target &> /dev/null && {
            mac=$(arp $target | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
            if [[ $mac ]]; then
                vendor=$(curl -s "https://api.macvendors.com/$mac")
            else
                mac="Bilinmiyor"
                vendor="?"
            fi

            echo -e "\n💻 Cihaz Bulundu: $target" | tee -a logs/scan_result.txt
            echo -e "   ↪ MAC: $mac" | tee -a logs/scan_result.txt
            echo -e "   ↪ Üretici: $vendor" | tee -a logs/scan_result.txt

            echo "   ↪ Açık Portlar:" | tee -a logs/scan_result.txt
            for port in 21 22 23 80 443 445 3389; do
                timeout 1 bash -c "echo >/dev/tcp/$target/$port" 2>/dev/null &&
                    echo "     • $port açık" | tee -a logs/scan_result.txt
            done
        }) &
    done
    wait

    echo -e "\n✅ Tarama Tamamlandı. Kayıt: logs/scan_result.txt\n"
}
