curl --request POST \
  --url https://api.minimaxi.com/v1/voice_design \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '
{
  "prompt": "讲述悬疑故事的播音员，声音低沉富有磁性，语速时快时慢，营造紧张神秘的氛围。",
  "preview_text": "夜深了，古屋里只有他一人。窗外传来若有若无的脚步声，他屏住呼吸，慢慢地，慢慢地，走向那扇吱呀作响的门……"
}
'
{
  "trial_audio": "hex 编码音频",
  "voice_id": "ttv-voice-2025060717322425-xxxxxxxx",
  "base_resp": {
    "status_code": 0,
    "status_msg": "success"
  }
}
