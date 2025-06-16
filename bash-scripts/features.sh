install_codecs() {
  section "Instalando codecs de áudio e vídeo"
  install_packages gst-libav gst-plugins-good gst-plugins-ugly ffmpeg
}

install_amd_drivers() {
  section "Instalando drivers AMD"
  install_packages xf86-video-amdgpu mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon
}

install_bluetooth() {
  section "Configurando Bluetooth"
  install_packages bluez bluez-utils bluez-libs
  sudo systemctl enable bluetooth.service
  sudo systemctl start bluetooth.service
}

