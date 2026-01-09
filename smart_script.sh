#!/system/bin/sh

# Script untuk otomatisasi mode performa berdasarkan aplikasi/game
# Simpan sebagai: /data/adb/service.d/gaming_perf.sh
# Pastikan executable: chmod +x /data/adb/service.d/gaming_perf.sh

# Konfigurasi
LOG_FILE="/data/adb/smart_script.log"
CONFIG_FILE="/data/adb/smart_script.conf"
SCREEN_STATE="/sys/class/backlight/panel0-backlight/brightness"
PROCESS_CHECK_INTERVAL=2

# Deteksi jumlah CPU cores
CPU_COUNT=$(cat /sys/devices/system/cpu/present | cut -d'-' -f2)
CPU_COUNT=$((CPU_COUNT + 1))
log_message "Detected CPU cores: $CPU_COUNT"

# Daftar game (bisa dikustomisasi)
GAME_LIST="com.pubg.krmobile
com.mobile.legends
com.levelinfinite.sgameGlobal
com.roblox.client
com.dts.freefireth
com.activision.callofduty.shooter
com.miHoYo.GenshinImpact
com.tencent.ig
com.ea.gp.fifamobile
com.supercell.clashofclans
net.wargaming.wot.blitz
com.nekki.shadowfight
com.mojang.minecraftpe
com.garena.game.codm
com.tencent.tmgp.sgame
com.riotgames.league.wildrift
com.netease.game.harrypotter
com.epicgames.fortnite
com.tencent.tmgp.pubgmhd
com.vng.mlbbvn"

# Daftar aplikasi berat (bisa dikustomisasi)
HEAVY_APP_LIST="com.google.android.youtube
com.instagram.android
com.facebook.katana
com.whatsapp
com.android.chrome
com.spotify.music
com.tiktok.android
com.zhiliaoapp.musically
com.snapchat.android
com.linkedin.android
com.netflix.mediaclient
com.amazon.avod.thirdpartyclient"

# Fungsi logging
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Fungsi baca konfigurasi
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        . "$CONFIG_FILE"
    else
        # Default configuration
        POWERSAVE_CPU_MAX="70%"
        POWERSAVE_GPU_MAX="60%"
        POWERSAVE_CORES_ONLINE=2  # Matiin 4 core jika total 6 core (6-4=2)
        
        BALANCE_CPU_MAX="85%"
        BALANCE_GPU_MAX="75%"
        BALANCE_CORES_ONLINE="all"  # Semua core aktif
        
        PERFORMANCE_CPU_MAX="100%"
        PERFORMANCE_GPU_MAX="100%"
        PERFORMANCE_CORES_ONLINE="all"  # Semua core aktif
        
        SAVE_CONFIG=1
    fi
}

# Fungsi simpan konfigurasi
save_config() {
    if [ "$SAVE_CONFIG" = "1" ]; then
        cat > "$CONFIG_FILE" << EOF
POWERSAVE_CPU_MAX="$POWERSAVE_CPU_MAX"
POWERSAVE_GPU_MAX="$POWERSAVE_GPU_MAX"
POWERSAVE_CORES_ONLINE="$POWERSAVE_CORES_ONLINE"
BALANCE_CPU_MAX="$BALANCE_CPU_MAX"
BALANCE_GPU_MAX="$BALANCE_GPU_MAX"
BALANCE_CORES_ONLINE="$BALANCE_CORES_ONLINE"
PERFORMANCE_CPU_MAX="$PERFORMANCE_CPU_MAX"
PERFORMANCE_GPU_MAX="$PERFORMANCE_GPU_MAX"
PERFORMANCE_CORES_ONLINE="$PERFORMANCE_CORES_ONLINE"
EOF
    fi
}

# Fungsi kontrol CPU cores
control_cpu_cores() {
    local online_cores=$1
    local governor=$2
    
    if [ "$online_cores" = "all" ]; then
        # Aktifkan semua core
        for i in $(seq 0 $((CPU_COUNT - 1))); do
            echo "1" > /sys/devices/system/cpu/cpu$i/online 2>/dev/null
            echo "$governor" > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor 2>/dev/null
            log_message "CPU$i: ON - Governor: $governor"
        done
    else
        # Matiin sebagian core (untuk powersave)
        local cores_to_keep=$online_cores
        
        # Pertama aktifkan semua core dulu
        for i in $(seq 0 $((CPU_COUNT - 1))); do
            echo "1" > /sys/devices/system/cpu/cpu$i/online 2>/dev/null
        done
        
        # Matiin core yang tidak diperlukan (dimulai dari core besar)
        for i in $(seq $((CPU_COUNT - 1)) -1 $cores_to_keep); do
            echo "0" > /sys/devices/system/cpu/cpu$i/online 2>/dev/null
            log_message "CPU$i: OFF (PowerSave)"
        done
        
        # Set governor untuk core yang masih aktif
        for i in $(seq 0 $((cores_to_keep - 1))); do
            echo "$governor" > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor 2>/dev/null
            log_message "CPU$i: ON - Governor: $governor"
        done
    fi
}

# Fungsi cek screen state
is_screen_on() {
    local brightness=$(cat "$SCREEN_STATE" 2>/dev/null || echo "100")
    if [ "$brightness" -gt 0 ]; then
        return 0  # Screen is on
    else
        return 1  # Screen is off
    fi
}

# Fungsi set mode powersave ultra
set_powersave_ultra() {
    log_message "Setting PowerSave Ultra mode"
    
    # Kontrol CPU cores - matiin 4 core, sisakan 2 core aktif
    control_cpu_cores "$POWERSAVE_CORES_ONLINE" "powersave"
    
    # CPU frequency settings untuk core yang masih aktif
    for i in $(seq 0 $((POWERSAVE_CORES_ONLINE - 1))); do
        echo "$POWERSAVE_CPU_MAX" > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq 2>/dev/null
        echo "powersave" > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor 2>/dev/null
    done
    
    # GPU settings (jika ada)
    if [ -f "/sys/class/kgsl/kgsl-3d0/devfreq/governor" ]; then
        echo "powersave" > /sys/class/kgsl/kgsl-3d0/devfreq/governor 2>/dev/null
        echo "$POWERSAVE_GPU_MAX" > /sys/class/kgsl/kgsl-3d0/max_gpuclk 2>/dev/null
    fi
    
    # Memory management
    echo "1" > /proc/sys/vm/swappiness 2>/dev/null
    echo "100" > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
    
    # Thermal throttling lebih agresif
    if [ -f "/sys/class/thermal/thermal_zone0/trip_point_0_temp" ]; then
        echo "10" > /sys/class/thermal/thermal_zone0/trip_point_0_temp 2>/dev/null
    fi
    
    log_message "PowerSave Ultra: Only $POWERSAVE_CORES_ONLINE cores active, governor=powersave"
}

# Fungsi set mode balance
set_balance_mode() {
    log_message "Setting Balance mode"
    
    # Aktifkan semua core dengan governor schedutil
    control_cpu_cores "all" "schedutil"
    
    # CPU frequency settings
    for i in $(seq 0 $((CPU_COUNT - 1))); do
        echo "$BALANCE_CPU_MAX" > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq 2>/dev/null
        echo "schedutil" > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor 2>/dev/null
    done
    
    # GPU settings
    if [ -f "/sys/class/kgsl/kgsl-3d0/devfreq/governor" ]; then
        echo "simple_ondemand" > /sys/class/kgsl/kgsl-3d0/devfreq/governor 2>/dev/null
        echo "$BALANCE_GPU_MAX" > /sys/class/kgsl/kgsl-3d0/max_gpuclk 2>/dev/null
    fi
    
    # Memory management
    echo "60" > /proc/sys/vm/swappiness 2>/dev/null
    echo "150" > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
    
    log_message "Balance: All $CPU_COUNT cores active, governor=schedutil"
}

# Fungsi set mode performance maksimal
set_performance_mode() {
    log_message "Setting Performance Max mode"
    
    # Aktifkan semua core dengan governor performance
    control_cpu_cores "all" "performance"
    
    # CPU frequency settings
    for i in $(seq 0 $((CPU_COUNT - 1))); do
        echo "$PERFORMANCE_CPU_MAX" > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq 2>/dev/null
        echo "performance" > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor 2>/dev/null
    done
    
    # GPU settings
    if [ -f "/sys/class/kgsl/kgsl-3d0/devfreq/governor" ]; then
        echo "performance" > /sys/class/kgsl/kgsl-3d0/devfreq/governor 2>/dev/null
        echo "$PERFORMANCE_GPU_MAX" > /sys/class/kgsl/kgsl-3d0/max_gpuclk 2>/dev/null
    fi
    
    # Disable some power saving features
    if [ -f "/sys/module/msm_thermal/parameters/enabled" ]; then
        echo "0" > /sys/module/msm_thermal/parameters/enabled 2>/dev/null
    fi
    
    echo "100" > /proc/sys/vm/swappiness 2>/dev/null
    echo "200" > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
    
    log_message "Performance: All $CPU_COUNT cores active, governor=performance"
}

# Fungsi cek apakah process adalah game
is_game() {
    local process=$1
    for game in $GAME_LIST; do
        if echo "$process" | grep -q "$game"; then
            return 0
        fi
    done
    return 1
}

# Fungsi cek apakah process adalah heavy app
is_heavy_app() {
    local process=$1
    for app in $HEAVY_APP_LIST; do
        if echo "$process" | grep -q "$app"; then
            return 0
        fi
    done
    return 1
}

# Fungsi dapatkan foreground app
get_foreground_app() {
    # Method 1: dumpsys activity
    local fg_app=$(dumpsys activity activities | grep "mResumedActivity" | awk '{print $4}' | cut -d'/' -f1)
    
    if [ -z "$fg_app" ]; then
        # Method 2: dumpsys window
        fg_app=$(dumpsys window | grep "mCurrentFocus" | awk -F'/' '{print $1}' | awk '{print $NF}')
    fi
    
    echo "$fg_app"
}

# Main loop
main() {
    log_message "Starting Gaming Performance Manager"
    log_message "Total CPU cores detected: $CPU_COUNT"
    load_config
    save_config
    
    # Hitung jumlah core untuk powersave (matiin 4 core)
    if [ "$CPU_COUNT" -ge 6 ]; then
        POWERSAVE_CORES_ONLINE=2  # Untuk 6-core: 6-4=2 core aktif
    elif [ "$CPU_COUNT" -eq 4 ]; then
        POWERSAVE_CORES_ONLINE=2  # Untuk 4-core: 4-2=2 core aktif
    else
        POWERSAVE_CORES_ONLINE=1  # Untuk lainnya: sisakan 1 core
    fi
    
    log_message "PowerSave will keep $POWERSAVE_CORES_ONLINE cores online"
    
    local current_mode=""
    local last_app=""
    
    while true; do
        # Cek keadaan layar
        if ! is_screen_on; then
            # Layar mati, set powersave ultra
            if [ "$current_mode" != "powersave" ]; then
                set_powersave_ultra
                current_mode="powersave"
                log_message "Screen off - PowerSave Ultra activated"
            fi
            sleep 5
            continue
        fi
        
        # Layar menyala, cek foreground app
        local fg_app=$(get_foreground_app)
        
        if [ -n "$fg_app" ] && [ "$fg_app" != "$last_app" ]; then
            log_message "Foreground app changed to: $fg_app"
            last_app="$fg_app"
            
            # Tentukan mode berdasarkan jenis aplikasi
            if is_game "$fg_app"; then
                if [ "$current_mode" != "performance" ]; then
                    set_performance_mode
                    current_mode="performance"
                    log_message "Game detected: $fg_app - Performance mode activated"
                fi
            elif is_heavy_app "$fg_app"; then
                if [ "$current_mode" != "balance" ]; then
                    set_balance_mode
                    current_mode="balance"
                    log_message "Heavy app detected: $fg_app - Balance mode activated"
                fi
            else
                # Default untuk app biasa
                if [ "$current_mode" != "balance" ]; then
                    set_balance_mode
                    current_mode="balance"
                    log_message "Regular app: $fg_app - Balance mode activated"
                fi
            fi
        fi
        
        sleep "$PROCESS_CHECK_INTERVAL"
    done
}

# Jalankan script
main &