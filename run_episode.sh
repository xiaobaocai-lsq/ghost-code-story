#!/bin/bash
# 《幽灵代码》多Agent工作流程协调器
# 用法: ./run_episode.sh [episode_number]
# 示例: ./run_episode.sh 001

set -e

EPISODE=$(printf "%03d" "${1:-1}")
PROJECT_DIR="/home/risky/claude_wkspace/ghost-code-story"
EP_DIR="$PROJECT_DIR/episode-$EPISODE"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  《幽灵代码》制作流程 - 第${EPISODE}话${NC}"
echo -e "${BLUE}========================================${NC}"

# 检查episode目录
if [ ! -d "$EP_DIR" ]; then
    echo -e "${RED}错误: episode-$EPISODE 目录不存在${NC}"
    exit 1
fi

# 阶段1: 导演 - 话大纲
echo ""
echo -e "${YELLOW}[阶段1] 导演审核话大纲${NC}"
if [ -f "$EP_DIR/outline_approved.md" ]; then
    echo -e "${GREEN}✓ 话大纲已审核通过${NC}"
else if [ -f "$EP_DIR/outline.md" ]; then
    echo "  发现话大纲，等待导演审核..."
    echo "  请运行导演Agent审核: $EP_DIR/outline.md"
    echo "  审核通过后保存为: outline_approved.md"
else
    echo -e "${RED}✗ 话大纲不存在${NC}"
    echo "  请先创建: $EP_DIR/outline.md"
    exit 1
fi
fi

# 阶段2: 编剧 - 分镜脚本
echo ""
echo -e "${YELLOW}[阶段2] 编剧产出分镜脚本${NC}"
if [ -f "$EP_DIR/script/script_approved.md" ]; then
    echo -e "${GREEN}✓ 分镜脚本已审核通过${NC}"
else if [ -f "$EP_DIR/script/script.md" ]; then
    echo "  发现分镜脚本，等待导演审核..."
    echo "  请运行导演Agent审核: $EP_DIR/script/script.md"
    echo "  审核通过后保存为: script_approved.md"
else
    echo -e "${RED}✗ 分镜脚本不存在${NC}"
    echo "  请先运行编剧Agent产出脚本"
    exit 1
fi
fi

# 阶段3: 视频组 + 声音组 (可并行)
echo ""
echo -e "${YELLOW}[阶段3] 制作阶段 (视频组 + 声音组)${NC}"

# 视频组
if [ -d "$EP_DIR/images" ] && [ "$(ls -A $EP_DIR/images/*.jpg 2>/dev/null | wc -l)" -gt 0 ]; then
    echo -e "${GREEN}✓ 视频组产出完成${NC} ($(ls $EP_DIR/images/*.jpg 2>/dev/null | wc -l) 张关键帧)"
else
    echo -e "${YELLOW}→ 视频组需要生成关键帧${NC}"
fi

# 声音组
if [ -d "$EP_DIR/audio/voice" ] && [ "$(ls -A $EP_DIR/audio/voice/*.mp3 2>/dev/null | wc -l)" -gt 0 ]; then
    echo -e "${GREEN}✓ 声音组产出完成${NC}"
    echo "  - 配音: $(ls $EP_DIR/audio/voice/*.mp3 2>/dev/null | wc -l) 个"
    [ -d "$EP_DIR/audio/bgm" ] && echo "  - BGM: $(ls $EP_DIR/audio/bgm/*.mp3 2>/dev/null | wc -l) 个"
    [ -d "$EP_DIR/audio/sfx" ] && echo "  - 音效: $(ls $EP_DIR/audio/sfx/*.mp3 2>/dev/null | wc -l) 个"
else
    echo -e "${YELLOW}→ 声音组需要生成音轨${NC}"
fi

# 阶段4: 字幕组
echo ""
echo -e "${YELLOW}[阶段4] 字幕组产出${NC}"
if [ -f "$EP_DIR/subtitles/dialogue.srt" ]; then
    echo -e "${GREEN}✓ 字幕组产出完成${NC}"
else
    echo -e "${YELLOW}→ 字幕组需要生成字幕文件${NC}"
fi

# 阶段5: 合成组
echo ""
echo -e "${YELLOW}[阶段5] 合成组制作最终视频${NC}"
if [ -f "$EP_DIR/output/ghost_code_ep${EPISODE}.mp4" ]; then
    SIZE=$(ls -lh "$EP_DIR/output/ghost_code_ep${EPISODE}.mp4" 2>/dev/null | awk '{print $5}')
    DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$EP_DIR/output/ghost_code_ep${EPISODE}.mp4" 2>/dev/null)
    echo -e "${GREEN}✓ 最终视频已生成${NC}"
    echo "  - 大小: $SIZE"
    echo "  - 时长: ${DUR}秒"
else
    echo -e "${YELLOW}→ 合成组需要合成最终视频${NC}"
fi

# 总结
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  当前进度${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "阶段完成度:"
[ -f "$EP_DIR/outline_approved.md" ] && echo -e "  ${GREEN}✓${NC} 话大纲" || echo -e "  ${RED}✗${NC} 话大纲"
[ -f "$EP_DIR/script/script_approved.md" ] && echo -e "  ${GREEN}✓${NC} 分镜脚本" || echo -e "  ${RED}✗${NC} 分镜脚本"
[ -d "$EP_DIR/images" ] && [ "$(ls -A $EP_DIR/images/*.jpg 2>/dev/null | wc -l)" -gt 0 ] && echo -e "  ${GREEN}✓${NC} 关键帧" || echo -e "  ${YELLOW}○${NC} 关键帧"
[ -f "$EP_DIR/audio/mix_track.mp3" ] && echo -e "  ${GREEN}✓${NC} 音频混音" || echo -e "  ${YELLOW}○${NC} 音频混音"
[ -f "$EP_DIR/subtitles/dialogue.srt" ] && echo -e "  ${GREEN}✓${NC} 字幕" || echo -e "  ${YELLOW}○${NC} 字幕"
[ -f "$EP_DIR/output/ghost_code_ep${EPISODE}.mp4" ] && echo -e "  ${GREEN}✓${NC} 最终视频" || echo -e "  ${YELLOW}○${NC} 最终视频"
echo ""

# 启动下一环节的提示
if [ ! -f "$EP_DIR/outline_approved.md" ]; then
    echo -e "${YELLOW}下一步: 请先完成话大纲并请导演审核${NC}"
elif [ ! -f "$EP_DIR/script/script_approved.md" ]; then
    echo -e "${YELLOW}下一步: 请运行编剧Agent产出分镜脚本${NC}"
elif [ ! -f "$EP_DIR/output/ghost_code_ep${EPISODE}.mp4" ]; then
    echo -e "${YELLOW}下一步: 视频/声音/字幕完成后，运行合成脚本${NC}"
else
    echo -e "${GREEN}第${EPISODE}话制作完成!${NC}"
fi

echo ""
