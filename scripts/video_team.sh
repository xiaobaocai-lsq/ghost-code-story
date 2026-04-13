#!/bin/bash
# 视频组执行脚本
# 用法: ./video_team.sh EPISODE

set -e

EP=$(printf "%03d" "${1:-1}")
EP_DIR="/home/risky/claude_wkspace/ghost-code-story/episode-$EP"
SCRIPT_FILE="$EP_DIR/script/script_approved.md"
IMG_DIR="$EP_DIR/images"
CHAR_REF_DIR="$EP_DIR/char_ref"

TOKEN="sk-cp-1qwWyK5zmCpjX1DmfqRw1dNzKj5AAOkQGVLLyWCMAi4IvrsvCH2mzHkLwoC4BOFOS-H0kHxRjkOxFPPtnkkBmzDVH3NyDQH9gOePVPINxZeFwS24eor8yYI"
IMG_API="https://api.minimaxi.com/v1/image_generation"

FONT="/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc"
[ ! -f "$FONT" ] && FONT="/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc"

echo "[VIDEO TEAM] Episode $EP - 开始生成关键帧"

# 检查脚本是否存在
if [ ! -f "$SCRIPT_FILE" ]; then
    echo "[ERROR] 脚本文件不存在: $SCRIPT_FILE"
    exit 1
fi

# 创建输出目录
mkdir -p "$IMG_DIR"

# ========== 1. 图像生成函数 ==========
gen_image() {
    local name=$1
    local prompt=$2
    local output="$IMG_DIR/${name}.jpg"

    if [ -f "$output" ]; then
        echo "  [SKIP] $output 已存在"
        return 0
    fi

    echo "  [GEN] $name..."

    local response=$(curl -s --request POST \
        --url "$IMG_API" \
        --header "Authorization: Bearer $TOKEN" \
        --header "Content-Type: application/json" \
        --data "{
            \"model\": \"image-01\",
            \"prompt\": \"$prompt\",
            \"image_size\": \"1024x1024\",
            \"response_format\": \"base64\"
        }")

    echo "$response" | python3 -c "
import sys,json,base64
d=json.load(sys.stdin)
a=d.get('data',{}).get('image_base64',[])
if a and isinstance(a, list):
    a = a[0]
if a:
    b=base64.b64decode(a)
    open('$output','wb').write(b)
    print('  [OK] $name: {} bytes'.format(len(b)))
else:
    print('  [FAIL] $name')
" 2>&1 | head -5
}

# ========== 2. 生成过渡帧 ==========
generate_transition_frames() {
    local img1=$1
    local img2=$2
    local output_dir=$3
    local transition_name=$4
    local num_frames=${5:-30}

    mkdir -p "$output_dir"

    ffmpeg -framerate 2 -i "$img1" -framerate 2 -i "$img2" \
        -filter_complex "blend=all_expr='A*(1-t)+B*t'" \
        -vframes $num_frames \
        -y "${output_dir}/${transition_name}_%03d.jpg" 2>/dev/null

    echo "  [OK] 过渡帧: ${output_dir}/${transition_name}_%03d.jpg"
}

# ========== 3. 主流程 ==========

# 检查已有图片数量
existing=$(ls "$IMG_DIR"/*.jpg 2>/dev/null | wc -l)
echo "[VIDEO TEAM] 已有关键帧: $existing"

# 如果图片太少，需要生成更多
if [ $existing -lt 10 ]; then
    echo "  [WARN] 关键帧不足，需要生成..."

    # 场景提示词
    scenes=(
        "雪夜,居民楼,俯拍,1990年代中国,压抑氛围,胶片质感"
        "室内,旧木桌,枯萎的花,泛黄纸条,特写,温暖又萧索"
        "8岁男孩,窗台,旧棉袄,望向窗外雪,逆光,孤独感"
        "45岁男人,背影,手持电话,烟雾缭绕,紧张氛围"
        "门缝视角,黑暗,恐惧,主观镜头"
        "衣柜内部,黑暗,儿童蜷缩,阴影,创伤感"
        "蒙面人,黑影,只露出眼睛,冷酷,狼一般"
        "父亲跪地,双手被绑,决绝眼神,悲剧"
        "担架,白布,血迹,警车,红蓝灯闪烁"
        "公交车,雪景,男孩侧脸,空洞眼神"
    )

    idx=1
    for scene in "${scenes[@]}"; do
        gen_image "ep${EP}_scene_$(printf "%02d" $idx)" "$scene,电影感,阴暗色调"
        idx=$((idx + 1))
    done
fi

# 生成过渡帧
echo "  [STEP] 检查过渡帧..."

existing_transitions=$(ls "$IMG_DIR"/*_trans_*.jpg 2>/dev/null | wc -l)
if [ $existing_transitions -lt 5 ]; then
    echo "  [INFO] 生成过渡帧..."

    # 获取所有主图
    main_images=($(ls "$IMG_DIR"/ep${EP}_scene_*.jpg 2>/dev/null || ls "$IMG_DIR"/ep${EP}_page_*.jpg 2>/dev/null || echo ""))

    if [ ${#main_images[@]} -ge 2 ]; then
        i=0
        while [ $i -lt $((${#main_images[@]} - 1)) ]; do
            img1="${main_images[$i]}"
            img2="${main_images[$((i+1))]}"
            base1=$(basename "$img1" .jpg)
            base2=$(basename "$img2" .jpg)
            generate_transition_frames "$img1" "$img2" "$IMG_DIR" "trans_${base1}_${base2}" 15
            i=$((i + 1))
        done
    fi
fi

# 生成人物特写
echo "  [STEP] 检查人物特写..."

char_imgs=$(ls "$IMG_DIR"/ep${EP}_char_*.jpg 2>/dev/null | wc -l)
if [ $char_imgs -eq 0 ] && [ -d "$CHAR_REF_DIR" ]; then
    echo "  [INFO] 使用人物设定图..."
    for char_img in "$CHAR_REF_DIR"/*.jpg; do
        if [ -f "$char_img" ]; then
            ln -sf "$(realpath --relative-to="$IMG_DIR" "$char_img")" "$IMG_DIR/$(basename $char_img)"
        fi
    done
fi

# 最终统计
final_count=$(ls "$IMG_DIR"/*.jpg 2>/dev/null | wc -l)
transition_count=$(ls "$IMG_DIR"/*_trans_*.jpg 2>/dev/null | wc -l)

echo "[VIDEO TEAM] Episode $EP - 关键帧生成完成"
echo "  总帧数: $final_count"
echo "  过渡帧: $transition_count"
echo "  产出: $IMG_DIR/*.jpg"

exit 0