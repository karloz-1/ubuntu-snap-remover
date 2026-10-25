#!/usr/bin/env bash
set -euo pipefail

# Thx to the LinuxConfig team for sharing a guide on how to remove snapd on Ubuntu 26.04!
# https://linuxconfig.org/how-to-remove-snapd-on-ubuntu-26-04

RED="\e[31m"	# "${RED}${NC}"
GREEN="\e[32m"	# "${GREEN}${NC}"
YELLOW="\e[33m"	# "${YELLOW}${NC}"
CYAN="\e[36m"	# "${CYAN}${NC}"
NC="\e[0m"	# "${NC}${NC}"

echo -e "${YELLOW}This script does:${NC}"
echo -e "${YELLOW}1. Remove and purge all snapd packages${NC}"
echo -e "${YELLOW}2. Stop all snapd services${NC}"
echo -e "${YELLOW}3. Purge snapd via APT${NC}"
echo -e "${YELLOW}4. Remove automatically installed dependencies${NC}"
echo -e "${YELLOW}5. Prevent snapd from being reinstalled (Creating an APT preference file to pin snapd)${NC}"
echo -e "${YELLOW}6. Clean up leftover snap directories${NC}"
echo -e "${YELLOW}7. Install firefox via the *DEB* package through the official Mozilla APT repository${NC}"
echo -e "${YELLOW}8. Install Flatpak and Gnome software${NC}"
echo -e "${YELLOW}9. Install extra utilities${NC}"

while true; do
	read -p "Are you sure you want to continue?: [Y/n]: " REMOVE_SNAP_DECISION
	case "$REMOVE_SNAP_DECISION" in
		[yY]|[yY][eE][sS])
			# Activamos la sesion sudo, hasta que se acabe el script
			sudo -v
			while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
            		break
            		;;
        	[nN]|[nN][oO])
            		echo "Script cancelled by the user."
            		exit 0
            		;;
        	*)
            		echo "Invalid option. Please, enter 'y' o 'n'."
            		echo "----------------------------------------------"
            ;;
	esac
done

# -------------------------------------------------------------------------------
# 1. Remove and purge all snapd packages
# -------------------------------------------------------------------------------

# Comprueba si el comando "snap" existe antes de intentar guardar los paquetes.
if command -v snap &> /dev/null; then
    echo -e "${YELLOW}1. Removing and purging all snapd packages...${NC}"
    
    # Iniciamos un bucle infinito que romperemos cuando la lista esté vacía
    while true; do
        # Ejecuta la lista de paquetes de snaps, captura la primera columna y la guarda en el array
        mapfile -t snapPackages < <(snap list 2>/dev/null | awk 'NR>1 {print $1}')

        # Verifica si el array "snapPackages" está vacío.
        if [[ ${#snapPackages[@]} -eq 0 ]]; then
            echo -e "${GREEN}No more snap packages found. Cleanup complete!${NC}"
            break # Sale del bucle while ya que no quedan paquetes
        fi

        # Si no está vacío, entra a eliminar los paquetes capturados en esta iteración
        for package in "${snapPackages[@]}"; do
            echo -e "${CYAN}Removing: $package${NC}"
            sudo snap remove --purge "$package" || true
            echo -e "${GREEN}Done${NC}"
        done
        
        echo -e "${YELLOW}Checking for remaining or dependent snap packages...${NC}"
    done
else
    echo -e "${YELLOW}1. Snap command not found, skipping package removal...${NC}"
fi

# -------------------------------------------------------------------------------
# 2. Stop all snapd services
# -------------------------------------------------------------------------------

# Detener los servicios de snap para evitar problemas a la hora eliminar snap
echo -e "${CYAN}2. Stoping all snapd services...${NC}"
sudo systemctl daemon-reload > /dev/null 2>&1
sudo systemctl stop snapd snapd.socket snapd.seeded.service > /dev/null 2>&1 || true
echo -e "${GREEN}Done${NC}"

# -------------------------------------------------------------------------------
# 3. Purge snapd via APT
# -------------------------------------------------------------------------------

echo -e "${CYAN}3. Purging snapd via APT...${NC}"
sudo apt purge -y snapd > /dev/null 2>&1
echo -e "${GREEN}Done${NC}"

# -------------------------------------------------------------------------------
# 4. Remove automatically installed dependencies
# -------------------------------------------------------------------------------

echo -e "${CYAN}4. Removing automatically installed dependencies...${NC}"
sudo apt autoremove -y --purge > /dev/null 2>&1
echo -e "${GREEN}Done${NC}"

# -------------------------------------------------------------------------------
# 5. Prevent snapd from being reinstalled (Creating an APT preference file to pin snapd)
# -------------------------------------------------------------------------------

echo -e "${CYAN}5. Prevent snapd from being reinstalled (Creating an APT preference file to pin snapd)...${NC}"
sudo cp ./nosnap.pref /etc/apt/preferences.d/ > /dev/null 2>&1
echo -e "${GREEN}Done${NC}"

# -------------------------------------------------------------------------------
# 6. Clean up leftover snap directories
# -------------------------------------------------------------------------------

echo -e "${CYAN}6. Cleaning up leftover snap directories...${NC}"
sudo rm -rf /snap /var/snap > /dev/null 2>&1
sudo rm -rf /var/cache/snapd > /dev/null 2>&1
rm -rf ~/snap > /dev/null 2>&1
echo -e "${GREEN}Done${NC}"

# -------------------------------------------------------------------------------
# -------------------------------------------------------------------------------

echo -e "${CYAN}Restarting services...${NC}"
sudo systemctl daemon-reload > /dev/null 2>&1
echo -e "${GREEN}Done${NC}"

# -------------------------------------------------------------------------------
# 7. Install firefox via the *DEB* package through the official Mozilla APT repository
# -------------------------------------------------------------------------------

echo -e "${CYAN}7. Install firefox via the *DEB* package through the official Mozilla APT repository...${NC}"
sudo install -d -m 0755 /etc/apt/keyrings

if [ ! -f /etc/apt/keyrings/packages.mozilla.org.asc ]; then
	wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
	gpg -n -q --import --import-options import-show /etc/apt/keyrings/packages.mozilla.org.asc | awk '/pub/{getline; gsub(/^ +| +$/,""); if($0 == "35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3") print "\nThe key fingerprint matches ("$0").\n"; else print "\nVerification failed: the fingerprint ("$0") does not match the expected one.\n"}'
fi


sudo tee /etc/apt/sources.list.d/mozilla.sources > /dev/null << EOF
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF

sudo tee /etc/apt/preferences.d/mozilla > /dev/null << EOF
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

sudo apt-get update -qq
sudo apt install -y firefox

# -------------------------------------------------------------------------------
# 8. Install Flatpak and Gnome software
# -------------------------------------------------------------------------------

echo -e "${CYAN}8. Installing Flatpak and Gnome software...${NC}"
sudo apt install -y flatpak
sudo apt install -y gnome-software-plugin-flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# -------------------------------------------------------------------------------
# 9. Install extra utilities
# -------------------------------------------------------------------------------

echo -e "${CYAN}9. Installing extra utilities...${NC}"
sudo apt install -y software-properties-gtk

# -------------------------------------------------------------------------------
# Finish
# -------------------------------------------------------------------------------

echo -e "${GREEN}-------------------------------------------------------------------------------${NC}"
echo -e "${GREEN}¡Snapd was successfully removed from Ubuntu!${NC}"
echo -e "${YELLOW}¡Please restart your system to complete!${NC}"
