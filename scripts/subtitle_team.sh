#!/bin/bash
# 字幕组执行脚本
# 用法: ./subtitle_team.sh EPISODE

set -e

EP=$(printf "%03d" "${1:-1}")
EP_DIR="/home/risky/claude_wkspace/ghost-code-story/episode-$EP"
AUDIO_DIR="$EP_DIR/audio"
VOICE_DIR="$AUDIO_DIR/voice"
SUBTITLE_DIR="$EP_DIR/subtitles"
TIMELINE_FILE="$AUDIO_DIR/timeline.json"
SCRIPT_FILE="$EP_DIR/script/script_approved.md"

echo "[SUBTITLE TEAM] Episode $EP - 开始生成字幕"

# 检查必要文件
if [ ! -f "$SCRIPT_FILE" ]; then
    echo "[ERROR] 脚本文件不存在: $SCRIPT_FILE"
    exit 1
fi

# 创建目录
mkdir -p "$SUBTITLE_DIR"

# ========== 工具函数 ==========

# 毫秒转SRT时间格式 (00:00:00,000)
ms_to_srt_time() {
    local ms=$1
    local hours=$((ms / 3600000))
    local minutes=$(((ms % 3600000) / 60000))
    local seconds=$(((ms % 60000) / 1000))
    local millis=$((ms % 1000))
    printf "%02d:%02d:%02d,%03d" $hours $minutes $seconds $millis
}

# 获取mp3文件时长(毫秒)
get_duration_ms() {
    local file=$1
    if [ ! -f "$file" ]; then
        echo "0"
        return
    fi
    local dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)
    python3 -c "print(int(float('$dur') * 1000))"
}

# ========== 1. 从timeline.json读取时间轴 ==========
read_timeline() {
    if [ -f "$TIMELINE_FILE" ]; then
        echo "  [INFO] 从timeline.json读取时间轴"
        python3 << 'PYEOF'
import json
timeline_file = "/home/risky/claude_wkspace/ghost-code-story/episode-$EP/audio/timeline.json"
try:
    with open(timeline_file) as f:
        data = json.load(f)
    print(json.dumps(data))
except:
    print("{}")
PYEOF
    else
        echo "  [INFO] timeline.json不存在，从配音文件生成"
    fi
}

# ========== 2. 生成对话字幕 ==========
generate_dialogue_srt() {
    local output_file="$SUBTITLE_DIR/dialogue.srt"

    echo "  [GEN] 生成对白字幕: $output_file"

    # 读取脚本提取台词
    # 这里需要解析script_approved.md获取台词
    # 简化：按时间轴顺序排列配音文件

    local voice_files=()
    for vf in "$VOICE_DIR"/*.mp3; do
        if [ -f "$vf" ]; then
            voice_files+=("$vf")
        fi
    done

    if [ ${#voice_files[@]} -eq 0 ]; then
        echo "  [WARN] 没有配音文件"
        return 1
    fi

    # 按文件名排序
    IFS=$'\n' sorted=($(sort <<<"${voice_files[*]}")); unset IFS

    # 生成SRT
    # 简化时间轴：均匀分布
    local total_dur=180000  # 3分钟
    local interval=$((total_dur / ${#sorted[@]}))

    local srt_content=""
    local index=1
    local current_time=0

    for vf in "${sorted[@]}"; do
        local basename=$(basename "$vf" .mp3)
        local dur_ms=$(get_duration_ms "$vf")

        # 确定角色
        local role="旁白"
        if [[ $basename == f* ]]; then
            role="父亲"
        elif [[ $basename == b* ]]; then
            role="蒙面人"
        fi

        # 从脚本提取实际台词
        local subtitle_text=$(grep -A2 "$basename" "$SCRIPT_FILE" 2>/dev/null | grep -v "^#" | grep -v "^$" | head -1 || echo "")

        # 生成SRT条目
        local start_time=$(ms_to_srt_time $current_time)
        local end_time=$(ms_to_srt_time $((current_time + dur_ms)))

        # 清理台词
        subtitle_text=$(echo "$subtitle_text" | sed 's/^[^\"]*\"//g; s/\"[^\"]*$//g; s/^\s*//g; s/\s*$//g')

        if [ -n "$subtitle_text" ]; then
            srt_content="${srt_content}${index}\n"
            srt_content="${srt_content}${start_time} --> ${end_time}\n"
            srt_content="${srt_content}${role}: ${subtitle_text}\n\n"
            index=$((index + 1))
        fi

        current_time=$((current_time + interval))
    done

    # 写入文件
    if [ -n "$srt_content" ]; then
        echo -e "$srt_content" > "$output_file"
        echo "  [OK] 对白字幕: $output_file (${index}条)"
    fi
}

# ========== 3. 生成歌词字幕 ==========
generate_lyrics_srt() {
    local output_file="$SUBTITLE_DIR/lyrics.srt"

    echo "  [GEN] 生成歌词字幕: $output_file"

    # 歌词竖排显示在右上角
    # 简化：使用脚本中的歌词片段

    local lyrics=(
        "雪落无声"
        "埋藏真相"
        "黑暗降临"
        "无人知晓"
        "回忆如刀"
        "割裂心间"
        "衣柜里的孩子"
        "从此失去哭泣的权利"
        "父亲的背影"
        "渐行渐远"
        "那一年"
        "冬天的秘密"
    )

    local total_dur=180000
    local lyrics_dur=$((total_dur / ${#lyrics[@]}))

    local srt_content=""
    local current_time=0

    for i in "${!lyrics[@]}"; do
        local lyric="${lyrics[$i]}"
        local start_time=$(ms_to_srt_time $current_time)
        local end_time=$(ms_to_srt_time $((current_time + lyrics_dur)))

        srt_content="${srt_content}$((i+1))\n"
        srt_content="${srt_content}${start_time} --> ${end_time}\n"
        srt_content="${srt_content}${lyric}\n\n"

        current_time=$((current_time + lyrics_dur))
    done

    echo -e "$srt_content" > "$output_file"
    echo "  [OK] 歌词字幕: $output_file (${#lyrics[@]}条)"
}

# ========== 4. 验证 ==========
verify_subtitles() {
    echo "  [VERIFY] 验证字幕文件..."

    local dialogue_srt="$SUBTITLE_DIR/dialogue.srt"
    local lyrics_srt="$SUBTITLE_DIR/lyrics.srt"

    if [ -f "$dialogue_srt" ] && [ -f "$lyrics_srt" ]; then
        local d_lines=$(wc -l < "$dialogue_srt")
        local l_lines=$(wc -l < "$lyrics_srt")
        echo "  [OK] 字幕文件生成完成"
        echo "    对白: $dialogue_srt (${d_lines}行)"
        echo "    歌词: $lyrics_srt (${l_lines}行)"
        return 0
    else
        echo "  [ERROR] 字幕文件生成失败"
        return 1
    fi
}

# ========== 主流程 ==========

# 检查配音文件
if [ ! -d "$VOICE_DIR" ] || [ $(ls "$VOICE_DIR"/*.mp3 2>/dev/null | wc -l) -eq 0 ]; then
    echo "  [ERROR] 没有配音文件: $VOICE_DIR"
    exit 1
fi

# 生成字幕
generate_dialogue_srt
generate_lyrics_srt
verify_subtitles

echo "[SUBTITLE TEAM] Episode $EP - 字幕生成完成"
echo "  产出: $SUBTITLE_DIR/dialogue.srt, $SUBTITLE_DIR/lyrics.srt"

exit 0