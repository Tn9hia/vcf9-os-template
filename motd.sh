rm /etc/update-motd.d/* && touch /etc/update-motd.d/99-viettel && chmod +x /etc/update-motd.d/99-viettel && echo "#!/bin/bash
            clear
            echo -e ""
            cat << "EOF"
                    _____________
                   < Viettel IDC >
                    -------------
                        /
                  .--./
               .-(    ).
              (___.__)__)
            EOF
            echo -e ""

            echo " Hostname : $(hostname)"
            echo " OS       : $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
            echo " Kernel   : $(uname -r)"
            echo " Uptime   : $(uptime -p)"
            echo " CPU      : $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
            echo " Memory   : $(free -h | awk '/Mem:/ {print $3 "/" $2}')"" > /etc/update-motd.d/99-viettel