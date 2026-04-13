curl --request POST \
  --url https://api.minimaxi.com/v1/get_voice \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '
{
  "voice_type": "all"
}
'
{
  "system_voice": [
    {
      "voice_id": "Chinese (Mandarin)_Reliable_Executive",
      "description": [
        "一位沉稳可靠的中年男性高管声音，标准普通话，传递出值得信赖的感觉。"
      ],
      "voice_name": "沉稳高管",
      "created_time": "1970-01-01"
    },
    {
      "voice_id": "Chinese (Mandarin)_News_Anchor",
      "description": [
        "一位专业、播音腔的中年女性新闻主播，标准普通话。"
      ],
      "voice_name": "新闻女声",
      "created_time": "1970-01-01"
    }
  ],
  "voice_cloning": [
    {
      "voice_id": "test12345",
      "description": [],
      "created_time": "2025-08-20"
    },
    {
      "voice_id": "test12346",
      "description": [],
      "created_time": "2025-08-21"
    }
  ],
  "voice_generation": [
    {
      "voice_id": "ttv-voice-2025082011321125-2uEN0X1S",
      "description": [],
      "created_time": "2025-08-20"
    },
    {
      "voice_id": "ttv-voice-2025082014225025-ZCQt0U0k",
      "description": [],
      "created_time": "2025-08-20"
    }
  ],
  "base_resp": {
    "status_code": 0,
    "status_msg": "success"
  }
}
