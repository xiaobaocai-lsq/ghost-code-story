#!/bin/bash
# 合成组执行脚本
# 用法: ./compose_team.sh EPISODE

set -e

EP=$(printf "%03d" "${1:-1}")
EP_DIR="/home/risky/claude_wkspace/ghost-code-story/episode-$EP"
IMG_DIR="$EP_DIR/images"
AUDIO_DIR="$EP_DIR/audio"
SUBTITLE_DIR="$EP_DIR/subtitles"
OUTPUT_DIR="$EP_DIR/output"
VIDEO_OUT="$OUTPUT_DIR/ghost_code_ep${EP}.mp4"
SCRIPT_FILE="$EP_DIR/script/script_approved.md"
TIMELINE_FILE="$AUDIO_DIR/timeline.json"

FONT="/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc"
[ ! -f "$FONT" ] && FONT="/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc"

echo "[COMPOSE TEAM] Episode $EP - 开始合成视频"

# 检查必要文件
if [ ! -f "$SCRIPT_FILE" ]; then
    echo "[ERROR] 脚本文件不存在"
    exit 1
fi

if [ ! -f "$AUDIO_DIR/mix_track.mp3" ]; then
    echo "[ERROR] 混音文件不存在: $AUDIO_DIR/mix_track.mp3"
    exit 1
fi

# 创建目录
mkdir -p "$OUTPUT_DIR" /tmp/compose_$EP

# 收集素材
img_count=$(ls "$IMG_DIR"/*.jpg 2>/dev/null | wc -l)
audio_file="$AUDIO_DIR/mix_track.mp3"
dialogue_srt="$SUBTITLE_DIR/dialogue.srt"
lyrics_srt="$SUBTITLE_DIR/lyrics.srt"

echo "  [INFO] 关键帧: $img_count 张"
echo "  [INFO] 音频文件: $audio_file"

if [ $img_count -eq 0 ]; then
    echo "  [ERROR] 没有关键帧"
    exit 1
fi

# ========== 1. 获取总时长 ==========
echo "  [STEP1] 获取视频时长..."

if [ -f "$TIMELINE_FILE" ]; then
    total_dur=$(python3 -c "import json; t=json.load(open('$TIMELINE_FILE')); print(int(t.get('total_duration', 180)))" 2>/dev/null || echo "180")
else
    # 从音频获取时长
    total_dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$audio_file" 2>/dev/null | cut -d. -f1 || echo "180")
fi

echo "  [INFO] 总时长: ${total_dur}s"

# ========== 2. 生成视频片段 ==========
echo "  [STEP2] 生成视频片段..."

# 按时间顺序排列图片
# 简化版：每张图片平均分配时长
img_per_sec=$((total_dur / img_count))
if [ $img_per_sec -lt 3 ]; then
    img_per_sec=3  # 最少3秒
fi

# 创建片段列表
rm -f /tmp/compose_$EP/concat.txt
rm -f /tmp/compose_$EP/segment_*.mp4

# 过渡效果
TRANSITION_DURATION=1
TRANSITION_TYPE="xvfade"  # cross-fade

idx=0
for img in $(ls "$IMG_DIR"/*.jpg 2>/dev/null | sort -V); do
    fname=$(basename "$img" .jpg)
    duration=$img_per_sec
    seg_file="/tmp/compose_$EP/segment_$(printf "%03d" $idx).mp4"

    echo "    Processing: $fname (${duration}s)"

    # 生成视频片段：图片 -> 视频
    ffmpeg -loop 1 -i "$img" \
        -c:v libx264 -t $duration \
        -vf "scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2,fade=t=in:st=0:d=0.5,fade=t=out:st=$((duration-1)):d=1" \
        -pix_fmt yuv420p -y \
        "$seg_file" 2>/dev/null

    if [ -f "$seg_file" ]; then
        echo "file '$seg_file'" >> /tmp/compose_$EP/concat.txt
    fi

    idx=$((idx + 1))
done

# ========== 3. 合并视频片段 ==========
echo "  [STEP3] 合并视频..."

if [ -f "/tmp/compose_$EP/concat.txt" ] && [ $(wc -l < /tmp/compose_$EP/concat.txt) -gt 0 ]; then
    # 使用filter_complex进行过渡合并
    num_segments=$(wc -l < /tmp/compose_$EP/concat.txt)
    echo "  [INFO] 合并 $num_segments 个片段..."

    # 构建ffmpeg concat命令
    concat_inputs=""
    concat_filters=""
    for i in $(seq 0 $((num_segments - 1))); do
        seg="/tmp/compose_$EP/segment_$(printf "%03d" $i).mp4"
        if [ -f "$seg" ]; then
            concat_inputs="$concat_inputs -i $seg"
        fi
    done

    # 简单合并（不用过渡，效果更好控制）
    ffmpeg $concat_inputs \
        -filter_complex "concat=n=$num_segments:v=1:a=0" \
        -c:v libx264 -preset fast \
        -y /tmp/compose_$EP/video_no_audio.mp4 2>/dev/null

    echo "  [OK] 视频合并完成"
else
    echo "  [ERROR] 没有可合并的片段"
    exit 1
fi

# ========== 4. 添加音频 ==========
echo "  [STEP4] 添加音频..."

if [ -f "$audio_file" ]; then
    # 获取音频时长
    audio_dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$audio_file" 2>/dev/null || echo "0")
    video_dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 /tmp/compose_$EP/video_no_audio.mp4 2>/dev/null || echo "0")

    echo "  [INFO] 音频: ${audio_dur}s, 视频: ${video_dur}s"

    # 确保音画同步（截取较短的）
    min_dur=$(python3 -c "print(min(float('$audio_dur'), float('$video_dur')))")

    ffmpeg -i /tmp/compose_$EP/video_no_audio.mp4 \
        -i "$audio_file" \
        -c:v copy \
        -c:a aac -b:a 192k \
        -shortest \
        -y /tmp/compose_$EP/video_with_audio.mp4 2>/dev/null

    echo "  [OK] 音频添加完成"
else
    echo "  [WARN] 没有音频文件"
    cp /tmp/compose_$EP/video_no_audio.mp4 /tmp/compose_$EP/video_with_audio.mp4
fi

# ========== 5. 添加字幕 ==========
echo "  [STEP5] 添加字幕..."

# 检查字幕文件
has_subtitles=false
subtitle_filter=""

if [ -f "$dialogue_srt" ]; then
    echo "  [INFO] 添加对白字幕: $dialogue_srt"
    has_subtitles=true

    # ASS默认不支持竖排，用filter复杂实现
    # 简化：横向显示在底部
    subtitle_filter="subtitles=$dialogue_srt:force_style='FontName=$FONT,FontSize=24,PrimaryColour=&HFFFFFF&,OutlineColour=&H000000&,Outline=2,Bold=1'"
fi

if [ -f "$lyrics_srt" ]; then
    echo "  [INFO] 添加歌词字幕(右上角竖排): $lyrics_srt"
    has_subtitles=true

    # 歌词放在右上角
    # 需要特殊处理竖排 - 使用vf的drawtext配合rotate
    # 简化版本：横向显示在右上角
    if [ -n "$subtitle_filter" ]; then
        # 两个字幕叠加
        subtitle_filter="${subtitle_filter},subtitles=$lyrics_srt:force_style='FontName=$FONT,FontSize=18,PrimaryColour=&H00FFFF&,OutlineColour=&H000000&,Outline=1,Alignment=9'"
    else
        subtitle_filter="subtitles=$lyrics_srt:force_style='FontName=$FONT,FontSize=18,PrimaryColour=&H00FFFF&,OutlineColour=&H000000&,Outline=1,Alignment=9'"
    fi
fi

if [ "$has_subtitles" = true ]; then
    # 需要用filter处理字幕
    ffmpeg -i /tmp/compose_$EP/video_with_audio.mp4 \
        -vf "$subtitle_filter" \
        -c:a copy \
        -y "$VIDEO_OUT" 2>&1 | tail -10
else
    echo "  [WARN] 没有字幕文件，直接复制"
    cp /tmp/compose_$EP/video_with_audio.mp4 "$VIDEO_OUT"
fi

# ========== 6. 验证输出 ==========
echo "  [STEP6] 验证输出..."

if [ -f "$VIDEO_OUT" ]; then
    size=$(stat -c%s "$VIDEO_OUT" 2>/dev/null || stat -f%z "$VIDEO_OUT" 2>/dev/null)
    dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$VIDEO_OUT" 2>/dev/null || echo "0")
    echo "  [OK] 视频合成完成!"
    echo "    文件: $VIDEO_OUT"
    echo "    大小: $size bytes"
    echo "    时长: ${dur}s"
else
    echo "  [ERROR] 视频生成失败"
    exit 1
fi

# 清理
rm -rf /tmp/compose_$EP

echo "[COMPOSE TEAM] Episode $EP - 合成完成"
echo "  输出: $VIDEO_OUT"

exit 0