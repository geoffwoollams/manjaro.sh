#!/bin/bash
# https://manjaro.sh

trap "echo; exit" INT

if [ $(id -u) -ne 0 ] ; then
  echo Please run this script using sudo!
  exit 1;
fi

if [ $SUDO_USER == "" ] ; then
  echo Please use sudo to run this script!
  exit 1;
fi

m_kernel="612"
m_general=true
m_nopasswd=true
m_gaming=true
m_emu=false
m_opensnitch=false
m_is_intel=false
m_is_amd=false

vendor=$(lscpu | awk '/Vendor ID/{print $3}' | xargs)
if [[ "$vendor" == "GenuineIntel" ]]; then m_is_intel=true ;
elif [[ "$vendor" == "AuthenticAMD" ]]; then m_is_amd=true ;
fi

toggle_kernel() { if [ "$m_kernel" == "612" ] ; then m_kernel="613" ; else m_kernel="612" ; fi }
toggle_general() { if [ "$m_general" == true ] ; then m_general=false ; else m_general=true ; fi }
toggle_nopasswd() { if [ "$m_nopasswd" == true ] ; then m_nopasswd=false ; else m_nopasswd=true ; fi }
toggle_gaming() { if [ "$m_gaming" == true ] ; then m_gaming=false ; else m_gaming=true ; fi }
toggle_emu() { if [ "$m_emu" == true ] ; then m_emu=false ; else m_emu=true ; fi }
toggle_opensnitch() { if [ "$m_opensnitch" == true ] ; then m_opensnitch=false ; else m_opensnitch=true ; fi }

do_stuff() {
  if [ "$m_nopasswd" == true ] ; then
    echo "$SUDO_USER ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-nopasswd
    echo "Defaults:1000 !authenticate" >> /etc/sudoers.d/99-nopasswd
    echo 'polkit.addRule(function(action, subject) {reboot () {
  if (subject.isInGroup("wheel")) {
      return polkit.Result.YES;
  }
});' > /etc/polkit-1/rules.d/49-nopasswd_global.rules
  fi


  if [ "$m_general" == true ] ; then
    sed -Ei '/EnableAUR/s/^#//' /etc/pamac.conf
    sed -Ei '/CheckAURUpdates/s/^#//' /etc/pamac.conf

    usermod -aG disk $SUDO_USER

    pacman-mirrors -n --api --set-branch unstable
    #pacman-mirrors --fasttrack 5
  fi

  pacman -Syu --noconfirm

  if [ "$m_general" == true ] ; then
    mhwd-kernel -i linux$m_kernel ;
    pamac install --no-confirm linux$m_kernel linux$m_kernel-headers archlinux-keyring ;

    mhwd -a pci nonfree 0300 ;

    if [ "$m_is_intel" == true ] ; then
      pamac install --no-confirm intel-ucode
    fi

    if [ "$m_is_amd" == true ] ; then
      pamac install --no-confirm amd-ucode
    fi
  fi

  if [ "$m_gaming" == true ] ; then
    pamac install --no-confirm \
      flatpak libpamac-flatpak-plugin dosbox lutris prismlauncher retroarch \
      gamemode libdecor libretro-overlays libretro-shaders jre21-openjdk \
      retroarch-assets-ozone retroarch-assets-xmb fluidsynth xboxdrv \
      gamescope gvfs innoextract lib32-gamemode linux-steam-integration \
      steam steam-native-runtime vulkan-driver lib32-vulkan-driver \
      lib32-libappindicator-gtk2 xdg-desktop-portal-impl game-devices-udev \
      lib32-vkd3d lib32-vulkan-icd-loader vulkan-icd-loader ;

      flatpak install --or-update --noninteractive -y --system https://sober.vinegarhq.org/sober.flatpakref ;
      flatpak install --or-update --noninteractive -y --system flathub com.dosbox_x.DOSBox-X ;
  fi

  if [ "$m_emu" == true ] ; then
    pamac install --no-confirm \
      qemu-full qemu-img libvirt virt-install virt-manager virt-viewer \
      edk2-ovmf dnsmasq swtpm guestfs-tools libosinfo openbsd-netcat \
      vde2 bridge-utils dmidecode libguestfs

    usermod -a -G kvm,libvirt,libvirt-qemu $SUDO_USER

    echo 'export LIBVIRT_DEFAULT_URI="qemu:///system"' >> /home/$SUDO_USER/.bashrc

    sed -Ei '/unix_sock_group/s/^.*$/unix_sock_group = "libvirt"/' /etc/libvirt/libvirtd.conf
    sed -Ei '/unix_sock_rw_perms/s/^.*$/unix_sock_rw_perms = "0770"/' /etc/libvirt/libvirtd.conf

    setfacl -R -b /var/lib/libvirt/images/
    setfacl -R -m "u:${SUDO_USER}:rwX" /var/lib/libvirt/images/
    setfacl -m "d:u:${SUDO_USER}:rwx" /var/lib/libvirt/images/

    systemctl enable libvirtd.service

    if [ "$m_is_intel" == true ] ; then
      modprobe -r kvm_intel
      modprobe kvm_intel nested=1
      echo "options kvm_intel nested=1" | sudo tee /etc/modprobe.d/kvm-intel.conf

      sed -Ei '/GRUB_CMDLINE_LINUX=/s/=""/="intel_iommu=on iommu=pt"/' /etc/default/grub
    fi

    if [ "$m_is_amd" == true ] ; then
      modprobe -r kvm_amd
      modprobe kvm_amd nested=1
      echo "options kvm_amd nested=1" | sudo tee /etc/modprobe.d/kvm-amd.conf
      echo "options kvm_amd sev=1" | sudo tee /etc/modprobe.d/amd-sev.conf
    fi

    grub-mkconfig -o /boot/grub/grub.cfg
  fi

  if [ "$m_opensnitch" == true ] ; then
    pamac install --no-confirm opensnitch
    systemctl stop opensnitchd.service

    pamac build --no-confirm opensnitch-ebpf-module

    systemctl enable opensnitchd.service
    systemctl stop opensnitchd.service
  fi

  if [ "$m_general" == true ] ; then
    pamac install --no-confirm \
        flatpak libpamac-flatpak-plugin python-pywayland waylandpp \
        gimp gnome-disk-utility gparted partitionmanager keepass \
        mpv yt-dlp glfw openal visualvm flite lib32-glibc ffmpeg \
        remmina freerdp libsecret libvncserver weston wine-gecko \
        ffmpegthumbs kio-admin ghostscript gutenprint exfatprogs \
        vulcan-tools vkd3d python-pefile python-evdev umu-launcher \
        wine winetricks wine-mono mono mono-tools mono-addins ntfs-3g \
        protontricks sshfs android-udev papirus-icon-theme dotnet-sdk \
        iotop icoutils kimageformats libappimage veracrypt ventoy \
        taglib kio-extras linux-firmware unzip nmap whois chromium \
        wayland-protocols plasma-wayland-protocols kdialog vlc \
        firefox-ublock-origin firefox-decentraleyes

    pamac build --no-confirm \
        waydroid waydroid-helper waydroid-magisk waydroid-image-gapps \
        ttf-ms-win11-auto proton-ge-custom-bin wine-ge-custom 
        #vscodium vscodium-marketplace

    #waydroid init -s GAPPS
    #systemctl enable --now waydroid-container

    flatpak install --or-update --noninteractive -y --system flathub com.adobe.Reader
  fi

  #if [ "$m_gaming" = true ] ; then
  #  /bin/bash -c 'curl -Ls https://raw.githubusercontent.com/moraroy/NonSteamLaunchers-On-Steam-Deck/main/NonSteamLaunchers.sh | /bin/bash -s -- "Epic Games" "Amazon Games Launcher" "Battle.net" "EA App" "GOG Galaxy" "Humble Games Collection" "Itch.io" "Rockstar Games Launcher" "Ubisoft Connect"'
  #fi

  echo ""
  echo "manjaro.sh has finished. Please reboot!";
}

until [ "$selection" = "0" ]; do
  clear
  echo "manjaro.sh"
  echo "https://manjaro.sh"
  echo "A better starting point for Manjaro"
  echo ""
  echo "  Optional toggles:"

  if [ "$m_general" == true ] ; then
    echo "   	1) Kernel: $m_kernel"
  else
    echo "   	1) Kernel: unchanged"
  fi

  echo "   	2) manjaro.sh recommendations? $m_general"
  echo "   	3) NOPASSWD enabled for sudoers and polkit? $m_nopasswd"
  echo "   	4) Install gaming launchers and tools? $m_gaming";
  echo "   	5) Install emulation tools? $m_emu";
  echo "   	6) Install OpenSnitch firewall? $m_opensnitch";
  echo ""
  echo "   	y)  Start"
  echo "   	q)  Quit"
  echo ""
  read -n1 -r -p "" selection < /dev/tty
  echo ""

  case $selection in
    1 ) clear ; toggle_kernel ;;
    2 ) clear ; toggle_general ;;
    3 ) clear ; toggle_nopasswd ;;
    4 ) clear ; toggle_gaming ;;
    5 ) clear ; toggle_emu ;;
    6 ) clear ; toggle_opensnitch ;;
    q|Q ) clear ; exit ;;
    y|Y ) clear ; do_stuff; exit ;;
    * ) clear ;;
  esac
done

exit 0
