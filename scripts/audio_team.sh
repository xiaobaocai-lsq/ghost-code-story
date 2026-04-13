#!/bin/bash
# 声音组执行脚本
# 用法: ./audio_team.sh EPISODE

set -e

TOKEN="sk-cp-1qwWyK5zmCpjX1DmfqRw1dNzKj5AAOkQGVLLyWCMAi4IvrsvCH2mzHkLwoC4BOFOS-H0kHxRjkOxFPPtnkkBmzDVH3NyDQH9gOePVPINxZeFwS24eor8yYI"
VOICE_API="https://api.minimaxi.com/v1/t2a_v2"
MUSIC_API="https://api.minimaxi.com/v1/music_generation"

EP=$(printf "%03d" "${1:-1}")
EP_DIR="/home/risky/claude_wkspace/ghost-code-story/episode-$EP"
ASSET_DIR="/home/risky/claude_wkspace/ghost-code-story/assets/audio"
AUDIO_DIR="$EP_DIR/audio"
VOICE_DIR="$AUDIO_DIR/voice"
BGM_DIR="$AUDIO_DIR/bgm"
MIX_DIR="$AUDIO_DIR/mix"
SCRIPT_FILE="$EP_DIR/script/script_approved.md"

echo "[AUDIO TEAM] Episode $EP - 开始生成音频"

# 检查脚本是否存在
if [ ! -f "$SCRIPT_FILE" ]; then
    echo "[ERROR] 脚本文件不存在: $SCRIPT_FILE"
    exit 1
fi

# 创建目录
mkdir -p "$VOICE_DIR" "$BGM_DIR" "$MIX_DIR"

# ========== 1. 配音生成函数 ==========
gen_voice() {
    local name=$1
    local text=$2
    local voice_id=$3
    local speed=$4
    local file="$VOICE_DIR/$name.mp3"

    # 跳过空文本
    if [ -z "$text" ] || [ "$text" = "无" ] || [ "$text" = "(无声)" ]; then
        echo "  [SKIP] $name: 无台词"
        return 0
    fi

    if [ -f "$file" ]; then
        echo "  [SKIP] $name 已存在"
        return 0
    fi

    echo "  [GEN] $name: ${text:0:30}..."

    # 使用curl调用API
    local json_data="{\"model\": \"speech-2.8-hd\", \"text\": \"$text\", \"stream\": false, \"voice_setting\": {\"voice_id\": \"$voice_id\", \"speed\": $speed, \"vol\": 1, \"pitch\": 0}, \"audio_setting\": {\"sample_rate\": 32000, \"bitrate\": 128000, \"format\": \"mp3\", \"channel\": 1}}"

    local response=$(curl -s --request POST \
        --url "$VOICE_API" \
        --header "Authorization: Bearer $TOKEN" \
        --header "Content-Type: application/json" \
        --data "$json_data")

    # 解析响应
    local audio_data=$(echo "$response" | python3 -c "
import sys,json,binascii
try:
    d=json.load(sys.stdin)
    a=d.get('data',{}).get('audio','')
    if a:
        b=binascii.unhexlify(a)
        open('$file','wb').write(b)
        print('OK:'+str(len(b)))
    else:
        err=d.get('error','')
        print('FAIL:'+str(err))
except Exception as e:
    print('FAIL:'+str(e))
" 2>&1)

    if [[ "$audio_data" == OK:* ]]; then
        echo "  [OK] $name: ${audio_data#OK:}"
    else
        echo "  [FAIL] $name: $audio_data"
    fi
}

# ========== 2. BGM生成函数 ==========
gen_bgm() {
    local name=$1
    local prompt=$2
    local lyrics=$3
    local file="$BGM_DIR/$name.mp3"

    if [ -f "$file" ]; then
        echo "  [SKIP] BGM $name 已存在"
        return 0
    fi

    echo "  [GEN] BGM $name..."

    local response=$(curl -s --request POST \
        --url "$MUSIC_API" \
        --header "Authorization: Bearer $TOKEN" \
        --header "Content-Type: application/json" \
        --data "{
        \"model\": \"music-2.6\",
        \"prompt\": \"$prompt\",
        \"lyrics\": \"$lyrics\",
        \"audio_setting\": {\"sample_rate\": 44100, \"bitrate\": 256000, \"format\": \"mp3\"}
    }")

    echo "$response" | python3 -c "
import sys,json,binascii
try:
    d=json.load(sys.stdin)
    a=d.get('data',{}).get('audio','')
    if a:
        b=binascii.unhexlify(a)
        open('$file','wb').write(b)
        print('OK:'+str(len(b)))
    else:
        print('FAIL:no_audio')
except Exception as e:
    print('FAIL:'+str(e))
"
}

# ========== 3. 从脚本提取台词 ==========
extract_and_generate_voices() {
    echo "  [INFO] 解析剧本提取台词..."

    # 使用Python解析脚本并生成配音
    python3 << 'PYEOF'
import re
import os
import json
import subprocess
import binascii

script_file = os.environ.get('SCRIPT_FILE', '')
voice_dir = os.environ.get('VOICE_DIR', '')
token = os.environ.get('TOKEN', '')
voice_api = os.environ.get('VOICE_API', '')

if not script_file or not voice_dir:
    print("Error: Missing env vars")
    exit(1)

try:
    with open(script_file, 'r', encoding='utf-8') as f:
        content = f.read()
except Exception as e:
    print(f"Error reading script: {e}")
    exit(1)

dialogues = []

# 旁白模式
narrator_pattern = r'旁白[:：]\s*["""]([^"""]+)["""]'
for match in re.finditer(narrator_pattern, content):
    text = match.group(1).strip()
    if text and len(text) > 2:
        dialogues.append({
            'name': 'n{:02d}'.format(len([d for d in dialogues if d['type'] == 'narrator']) + 1),
            'type': 'narrator',
            'text': text,
            'voice_id': 'male-qn-qingse',
            'speed': 1.0
        })

# 父亲模式
father_pattern = r'父亲[^:：]*[:：]\s*["""]([^"""]+)["""]'
for match in re.finditer(father_pattern, content):
    text = match.group(1).strip()
    if text and len(text) > 2:
        dialogues.append({
            'name': 'f{:02d}'.format(len([d for d in dialogues if d['type'] == 'father']) + 1),
            'type': 'father',
            'text': text,
            'voice_id': 'male-qn-qingse',
            'speed': 0.95
        })

# 蒙面人模式
bandit_pattern = r'蒙面人[^:：]*[:：]\s*["""]([^"""]+)["""]'
for match in re.finditer(bandit_pattern, content):
    text = match.group(1).strip()
    if text and len(text) > 2:
        dialogues.append({
            'name': 'b{:02d}'.format(len([d for d in dialogues if d['type'] == 'bandit']) + 1),
            'type': 'bandit',
            'text': text,
            'voice_id': 'male-qn-qingse',
            'speed': 1.1
        })

# 老院长模式
elder_pattern = r'老院长[^:：]*[:：]\s*["""]([^"""]+)["""]'
for match in re.finditer(elder_pattern, content):
    text = match.group(1).strip()
    if text and len(text) > 2:
        dialogues.append({
            'name': 'e{:02d}'.format(len([d for d in dialogues if d['type'] == 'elder']) + 1),
            'type': 'elder',
            'text': text,
            'voice_id': 'female-shaonv',
            'speed': 0.95
        })

# 陆鸣模式
luming_pattern = r'陆鸣[^:：]*[:：]\s*["""]([^"""]+)["""]'
for match in re.finditer(luming_pattern, content):
    text = match.group(1).strip()
    if text and len(text) > 2:
        dialogues.append({
            'name': 'l{:02d}'.format(len([d for d in dialogues if d['type'] == 'luming']) + 1),
            'type': 'luming',
            'text': text,
            'voice_id': 'male-child',
            'speed': 1.0
        })

print(f"  [INFO] 提取到 {len(dialogues)} 条台词")

# 生成每个配音
for d in dialogues:
    name = d['name']
    text = d['text']
    voice_id = d['voice_id']
    speed = d['speed']

    out_file = os.path.join(voice_dir, name + '.mp3')
    if os.path.exists(out_file):
        print(f"  [SKIP] {name} 已存在")
        continue

    print(f"  [GEN] {name}: {text[:30]}...")

    json_data = {
        "model": "speech-2.8-hd",
        "text": text,
        "stream": False,
        "voice_setting": {
            "voice_id": voice_id,
            "speed": speed,
            "vol": 1,
            "pitch": 0
        },
        "audio_setting": {
            "sample_rate": 32000,
            "bitrate": 128000,
            "format": "mp3",
            "channel": 1
        }
    }

    try:
        req = subprocess.run([
            'curl', '-s', '--request', 'POST',
            '--url', voice_api,
            '--header', f'Authorization: Bearer {token}',
            '--header', 'Content-Type: application/json',
            '--data', json.dumps(json_data)
        ], capture_output=True, text=True, timeout=30)

        result = json.loads(req.stdout)
        audio = result.get('data', {}).get('audio', '')
        if audio:
            b = binascii.unhexlify(audio)
            with open(out_file, 'wb') as f:
                f.write(b)
            print(f"  [OK] {name}: {len(b)} bytes")
        else:
            err = result.get('error', 'unknown')
            print(f"  [FAIL] {name}: {err}")
    except Exception as e:
        print(f"  [FAIL] {name}: {e}")

print(f"  [INFO] 配音生成完成")
PYEOF
}

# ========== 4. 混音函数 ==========
mix_audio() {
    local mix_file="$AUDIO_DIR/mix_track.mp3"

    echo "  [MIX] 开始混音..."

    # 收集所有配音文件
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

    echo "  [INFO] 找到 ${#voice_files[@]} 个配音文件"

    # 检查BGM
    local bgm_file=""
    if [ -f "$BGM_DIR/bgm_main.mp3" ]; then
        bgm_file="$BGM_DIR/bgm_main.mp3"
    elif [ -f "$ASSET_DIR/bgm.mp3" ]; then
        bgm_file="$ASSET_DIR/bgm.mp3"
    fi

    local total_dur=180
    if [ -f "$SCRIPT_FILE" ]; then
        local dur_match=$(grep -oE "[0-9]+秒" "$SCRIPT_FILE" | head -1 | grep -oE "[0-9]+" || echo "180")
        total_dur=${dur_match:-180}
    fi

    # 处理BGM
    if [ -n "$bgm_file" ] && [ -f "$bgm_file" ]; then
        echo "  [STEP1] 处理BGM..."
        local bgm_dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$bgm_file" 2>/dev/null || echo "180")

        if python3 -c "exit(0 if float('$bgm_dur') >= float('$total_dur') else 1)" 2>/dev/null; then
            ffmpeg -i "$bgm_file" -t "$total_dur" -y "$MIX_DIR/bgm_padded.mp3" 2>/dev/null
        else
            ffmpeg -stream_loop -1 -i "$bgm_file" -af "apad=whole_dur=${total_dur}" -t "$total_dur" -y "$MIX_DIR/bgm_padded.mp3" 2>/dev/null
        fi
        echo "  [INFO] BGM: ${bgm_dur}s -> ${total_dur}s"
    else
        echo "  [WARN] 没有BGM，创建静音"
        ffmpeg -f lavfi -i "anullsrc=r=44100:cl=stereo" -t "$total_dur" -y "$MIX_DIR/bgm_padded.mp3" 2>/dev/null
    fi

    # 拼接配音
    echo "  [STEP2] 拼接配音..."
    local voices_concat="$MIX_DIR/voices_concat.txt"
    > "$voices_concat"

    for vf in "${voice_files[@]}"; do
        echo "file '$vf'" >> "$voices_concat"
    done

    ffmpeg -f concat -safe 0 -i "$voices_concat" -c copy -y "$MIX_DIR/voices_merged.mp3" 2>/dev/null

    # 最终混音
    echo "  [STEP3] 最终混音..."
    ffmpeg -i "$MIX_DIR/bgm_padded.mp3" \
        -i "$MIX_DIR/voices_merged.mp3" \
        -filter_complex "[0:a][1:a]amix=inputs=2:duration=first:dropout_transition=0:normalize=0[aout]" \
        -map "[aout]" \
        -t "$total_dur" \
        -ar 44100 \
        -ac 2 \
        -y "$mix_file" 2>&1 | tail -3

    if [ -f "$mix_file" ]; then
        local size=$(stat -c%s "$mix_file" 2>/dev/null || stat -f%z "$mix_file" 2>/dev/null)
        echo "  [OK] 混音完成: $mix_file ($size bytes)"
    else
        echo "  [FAIL] 混音失败"
        return 1
    fi
}

# ========== 主流程 ==========

export SCRIPT_FILE VOICE_DIR TOKEN VOICE_API

# 1. 检查配音
echo "  [STEP0] 检查配音..."
existing_voices=$(ls "$VOICE_DIR"/*.mp3 2>/dev/null | wc -l)
echo "  [INFO] 已有配音: $existing_voices 个"

if [ $existing_voices -eq 0 ]; then
    echo "  [INFO] 开始生成配音..."
    extract_and_generate_voices
else
    echo "  [SKIP] 配音已存在，跳过生成"
fi

# 2. 检查BGM
if [ ! -f "$BGM_DIR/bgm_main.mp3" ] && [ ! -f "$ASSET_DIR/bgm.mp3" ]; then
    echo "  [GEN] 生成BGM..."
    gen_bgm "main" "ambient,dark,tense,suspense,1990s China,cinematic,piano" "[verse]\n雪落无声\n埋藏真相"
else
    echo "  [SKIP] BGM已存在"
    [ -f "$ASSET_DIR/bgm.mp3" ] && [ ! -f "$BGM_DIR/bgm_main.mp3" ] && ln -sf "$ASSET_DIR/bgm.mp3" "$BGM_DIR/bgm_main.mp3"
fi

# 3. 执行混音
if [ -d "$VOICE_DIR" ] && [ $(ls "$VOICE_DIR"/*.mp3 2>/dev/null | wc -l) -gt 0 ]; then
    mix_audio
fi

echo "[AUDIO TEAM] Episode $EP - 音频工作完成"
echo "  配音: $VOICE_DIR/"
echo "  BGM: $BGM_DIR/"
echo "  混音: $AUDIO_DIR/mix_track.mp3"

exit 0