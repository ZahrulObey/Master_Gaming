#!/system/bin/sh
# MASTER GAMING SCRIPT - Stalin Gejul
# All-in-One: Performance + Efficiency + Screen-Aware Hotplug

LOG="/data/local/master_gaming.log"

# Tunggu boot selesai
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 5
done
sleep 10

echo "============================================" >> "$LOG"
echo "[$(date)] Master Gaming Script Started" >> "$LOG"
echo "============================================" >> "$LOG"

# ========================================
# PART 1: BASE PERFORMANCE SETUP
# ========================================
setup_base_performance() {
    echo "" >> "$LOG"
    echo ">>> PART 1: Base Performance Setup" >> "$LOG"
    
    # === THERMAL ===
    echo "disabled" > /sys/class/thermal/thermal_zone0/mode 2>/dev/null
    
    for zone in /sys/class/thermal/thermal_zone*/trip_point_0_temp; do
        echo 88000 > "$zone" 2>/dev/null
    done
    for zone in /sys/class/thermal/thermal_zone*/trip_point_1_temp; do
        echo 100000 > "$zone" 2>/dev/null
    done
    
    echo "enabled" > /sys/class/thermal/thermal_zone1/mode 2>/dev/null
    echo "enabled" > /sys/class/thermal/thermal_zone2/mode 2>/dev/null
    
    echo "  ✓ Thermal: 88/100°C" >> "$LOG"
    
    # === CPU GOVERNOR ===
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [ -f "$cpu" ]; then
            echo "performance" > "$cpu" 2>/dev/null
        fi
    done
    
    echo "  ✓ CPU: performance governor" >> "$LOG"
    
    # === GPU GOVERNOR ===
    GPU_DEVFREQ="/sys/class/devfreq/23100000.gpu"
    if [ -f "$GPU_DEVFREQ/governor" ]; then
        echo "performance" > "$GPU_DEVFREQ/governor" 2>/dev/null
        echo "  ✓ GPU: performance governor" >> "$LOG"
    fi
}

# ========================================
# PART 2: EFFICIENCY TWEAKS
# ========================================
setup_efficiency() {
    echo "" >> "$LOG"
    echo ">>> PART 2: Efficiency Tweaks" >> "$LOG"
    
    # === CPU FREQ RANGES ===
    # Big cores (A75: 0,1) - min 40%
    for cpu in 0 1; do
        BASE="/sys/devices/system/cpu/cpu${cpu}/cpufreq"
        if [ -d "$BASE" ]; then
            MAX=$(cat "$BASE/cpuinfo_max_freq" 2>/dev/null)
            MIN=$((MAX * 40 / 100))
            echo "$MIN" > "$BASE/scaling_min_freq" 2>/dev/null
        fi
    done
    
    # Little cores (A55: 2-7) - min 25%
    for cpu in 2 3 4 5 6 7; do
        BASE="/sys/devices/system/cpu/cpu${cpu}/cpufreq"
        if [ -d "$BASE" ]; then
            MAX=$(cat "$BASE/cpuinfo_max_freq" 2>/dev/null)
            MIN=$((MAX * 25 / 100))
            echo "$MIN" > "$BASE/scaling_min_freq" 2>/dev/null
        fi
    done
    
    echo "  ✓ CPU freq: Big 40%, Little 25% min" >> "$LOG"
    
    # === GPU FREQ ===
    MAX_GPU=$(cat "$GPU_DEVFREQ/max_freq" 2>/dev/null)
    if [ ! -z "$MAX_GPU" ]; then
        MIN_GPU=$((MAX_GPU * 30 / 100))
        echo "$MIN_GPU" > "$GPU_DEVFREQ/min_freq" 2>/dev/null
        echo "  ✓ GPU freq: 30% min" >> "$LOG"
    fi
    
    # === MALI PARAMETERS ===
    MALI_PARAMS="/sys/module/mali_kbase/parameters"
    if [ -f "$MALI_PARAMS/gpu_pollingtime" ]; then
        echo 20 > "$MALI_PARAMS/gpu_pollingtime" 2>/dev/null
        echo 65 > "$MALI_PARAMS/gpu_upthreshold" 2>/dev/null
        echo 15 > "$MALI_PARAMS/gpu_downdifferential" 2>/dev/null
        echo "  ✓ Mali: optimized polling" >> "$LOG"
    fi
    
    # === CPU IDLE ===
    echo 1 > /sys/devices/system/cpu/cpuidle/use_deepest_state 2>/dev/null
    echo "  ✓ CPU idle: deep sleep enabled" >> "$LOG"
    
    # === I/O SCHEDULER ===
    for queue in /sys/block/*/queue/scheduler; do
        echo "deadline" > "$queue" 2>/dev/null
    done
    for queue in /sys/block/*/queue/read_ahead_kb; do
        echo 512 > "$queue" 2>/dev/null
    done
    echo "  ✓ I/O: deadline + 512KB readahead" >> "$LOG"
    
    # === VM TUNING ===
    echo 10 > /proc/sys/vm/dirty_ratio 2>/dev/null
    echo 5 > /proc/sys/vm/dirty_background_ratio 2>/dev/null
    echo 10 > /proc/sys/vm/swappiness 2>/dev/null
    echo 50 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
    echo "  ✓ VM: optimized memory management" >> "$LOG"
    
    # === KERNEL TWEAKS ===
    echo 10000000 > /proc/sys/kernel/sched_min_granularity_ns 2>/dev/null
    echo 15000000 > /proc/sys/kernel/sched_wakeup_granularity_ns 2>/dev/null
    echo "  ✓ Kernel: reduced wakeups" >> "$LOG"
}

# ========================================
# PART 3: SCREEN-AWARE FUNCTIONS
# ========================================

# Function: Enable all cores (Screen ON)
enable_all_cores() {
    echo "" >> "$LOG"
    echo "[$(date)] >>> Screen ON - Full Performance Mode" >> "$LOG"
    
    # Online all cores
    for cpu in /sys/devices/system/cpu/cpu*/online; do
        CPU_NUM=$(echo "$cpu" | grep -o 'cpu[0-9]*' | grep -o '[0-9]*')
        if [ "$CPU_NUM" != "0" ]; then
            echo 1 > "$cpu" 2>/dev/null
        fi
    done
    
    # Restore performance governor
    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [ -f "$gov" ]; then
            echo "performance" > "$gov" 2>/dev/null
        fi
    done
    
    # Restore CPU freq ranges
    for cpu in 0 1; do
        BASE="/sys/devices/system/cpu/cpu${cpu}/cpufreq"
        if [ -d "$BASE" ]; then
            MAX=$(cat "$BASE/cpuinfo_max_freq" 2>/dev/null)
            MIN=$((MAX * 40 / 100))
            echo "$MIN" > "$BASE/scaling_min_freq" 2>/dev/null
        fi
    done
    
    for cpu in 2 3 4 5 6 7; do
        BASE="/sys/devices/system/cpu/cpu${cpu}/cpufreq"
        if [ -d "$BASE" ]; then
            MAX=$(cat "$BASE/cpuinfo_max_freq" 2>/dev/null)
            MIN=$((MAX * 25 / 100))
            echo "$MIN" > "$BASE/scaling_min_freq" 2>/dev/null
        fi
    done
    
    # GPU performance
    if [ -f "$GPU_DEVFREQ/governor" ]; then
        echo "performance" > "$GPU_DEVFREQ/governor" 2>/dev/null
    fi
    
    MAX_GPU=$(cat "$GPU_DEVFREQ/max_freq" 2>/dev/null)
    if [ ! -z "$MAX_GPU" ]; then
        MIN_GPU=$((MAX_GPU * 30 / 100))
        echo "$MIN_GPU" > "$GPU_DEVFREQ/min_freq" 2>/dev/null
    fi
    
    echo "  ✓ All cores online" >> "$LOG"
    echo "  ✓ Performance mode restored" >> "$LOG"
}

# Function: Disable cores (Screen OFF)
disable_cores() {
    echo "" >> "$LOG"
    echo "[$(date)] >>> Screen OFF - Ultra Power Save" >> "$LOG"
    
    # Offline cpu1-7
    for cpu in /sys/devices/system/cpu/cpu*/online; do
        CPU_NUM=$(echo "$cpu" | grep -o 'cpu[0-9]*' | grep -o '[0-9]*')
        if [ "$CPU_NUM" != "0" ]; then
            echo 0 > "$cpu" 2>/dev/null
        fi
    done
    
    # CPU0 powersave
    CPU0_BASE="/sys/devices/system/cpu/cpu0/cpufreq"
    if [ -d "$CPU0_BASE" ]; then
        echo "powersave" > "$CPU0_BASE/scaling_governor" 2>/dev/null
        echo 614400 > "$CPU0_BASE/scaling_min_freq" 2>/dev/null
    fi
    
    # GPU powersave
    if [ -f "$GPU_DEVFREQ/governor" ]; then
        echo "powersave" > "$GPU_DEVFREQ/governor" 2>/dev/null
    fi
    
    echo "  ✓ Only CPU0 online (powersave)" >> "$LOG"
    echo "  ✓ Ultra low power mode" >> "$LOG"
}

# Detect screen state
get_screen_state() {
    # Method 1: dumpsys display
    SCREEN=$(dumpsys display 2>/dev/null | grep -i "mScreenState" | head -1)
    if echo "$SCREEN" | grep -qi "ON"; then
        echo "on"
        return
    elif echo "$SCREEN" | grep -qi "OFF"; then
        echo "off"
        return
    fi
    
    # Method 2: power service
    SCREEN=$(dumpsys power 2>/dev/null | grep "Display Power" | head -1)
    if echo "$SCREEN" | grep -qi "ON"; then
        echo "on"
        return
    elif echo "$SCREEN" | grep -qi "OFF"; then
        echo "off"
        return
    fi
    
    # Method 3: input service
    SCREEN=$(dumpsys input 2>/dev/null | grep "mInteractive" | head -1)
    if echo "$SCREEN" | grep -qi "true"; then
        echo "on"
    else
        echo "off"
    fi
}

# ========================================
# MAIN EXECUTION
# ========================================

# Setup base performance & efficiency (one time)
setup_base_performance
setup_efficiency

echo "" >> "$LOG"
echo "============================================" >> "$LOG"
echo "Initial Setup Complete!" >> "$LOG"
echo "Starting screen monitoring loop..." >> "$LOG"
echo "============================================" >> "$LOG"

# Start screen monitoring loop (background)
PREV_STATE=""

while true; do
    CURRENT_STATE=$(get_screen_state)
    
    if [ "$CURRENT_STATE" != "$PREV_STATE" ]; then
        if [ "$CURRENT_STATE" = "off" ]; then
            sleep 5  # Debounce
            VERIFY=$(get_screen_state)
            if [ "$VERIFY" = "off" ]; then
                disable_cores
                PREV_STATE="off"
            fi
            
        elif [ "$CURRENT_STATE" = "on" ]; then
            enable_all_cores
            PREV_STATE="on"
        fi
    fi
    
    sleep 3
done &

echo "Service PID: $!" >> "$LOG"
echo "[$(date)] Master script running in background ✓" >> "$LOG"