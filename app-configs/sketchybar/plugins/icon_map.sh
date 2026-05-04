#!/bin/bash

# Icon map for applications using sketchybar-app-font
# Font: https://github.com/kvndrsslr/sketchybar-app-font

__icon_map() {
  case "$1" in
    "Finder"|"访达") icon_result=":finder:" ;;
    "Safari") icon_result=":safari:" ;;
    "Google Chrome"|"Chrome") icon_result=":google_chrome:" ;;
    "Firefox"|"firefox") icon_result=":firefox:" ;;
    "Arc") icon_result=":arc:" ;;
    "Brave Browser") icon_result=":brave_browser:" ;;
    "Microsoft Edge") icon_result=":microsoft_edge:" ;;
    "Vivaldi") icon_result=":vivaldi:" ;;
    "Code"|"Visual Studio Code") icon_result=":code:" ;;
    "Cursor") icon_result=":cursor:" ;;
    "Xcode") icon_result=":xcode:" ;;
    "Neovide"|"neovide") icon_result=":neovide:" ;;
    "Terminal") icon_result=":terminal:" ;;
    "iTerm2"|"iTerm") icon_result=":iterm:" ;;
    "Warp") icon_result=":warp:" ;;
    "kitty") icon_result=":kitty:" ;;
    "Alacritty") icon_result=":alacritty:" ;;
    "Ghostty") icon_result=":ghostty:" ;;
    "Slack") icon_result=":slack:" ;;
    "Discord") icon_result=":discord:" ;;
    "Messages"|"信息") icon_result=":messages:" ;;
    "Telegram") icon_result=":telegram:" ;;
    "WhatsApp") icon_result=":whatsapp:" ;;
    "Microsoft Teams") icon_result=":microsoft_teams:" ;;
    "Zoom") icon_result=":zoom:" ;;
    "FaceTime") icon_result=":facetime:" ;;
    "Mail"|"邮件") icon_result=":mail:" ;;
    "Spark") icon_result=":spark:" ;;
    "Spotify") icon_result=":spotify:" ;;
    "Music"|"音乐") icon_result=":music:" ;;
    "VLC") icon_result=":vlc:" ;;
    "IINA") icon_result=":iina:" ;;
    "Podcast"|"播客") icon_result=":podcasts:" ;;
    "Notes"|"备忘录") icon_result=":notes:" ;;
    "Notion") icon_result=":notion:" ;;
    "Obsidian") icon_result=":obsidian:" ;;
    "Bear") icon_result=":bear:" ;;
    "Craft") icon_result=":craft:" ;;
    "Reminders"|"提醒事项") icon_result=":reminders:" ;;
    "Calendar"|"日历") icon_result=":calendar:" ;;
    "Fantastical") icon_result=":fantastical:" ;;
    "Things") icon_result=":things:" ;;
    "Todoist") icon_result=":todoist:" ;;
    "Preview"|"预览") icon_result=":preview:" ;;
    "Photos"|"照片") icon_result=":photos:" ;;
    "Figma") icon_result=":figma:" ;;
    "Sketch") icon_result=":sketch:" ;;
    "Adobe Photoshop 2024"|"Adobe Photoshop") icon_result=":adobe_photoshop:" ;;
    "Adobe Illustrator 2024"|"Adobe Illustrator") icon_result=":adobe_illustrator:" ;;
    "Affinity Designer") icon_result=":affinity_designer:" ;;
    "Affinity Photo") icon_result=":affinity_photo:" ;;
    "Blender") icon_result=":blender:" ;;
    "System Preferences"|"System Settings"|"系统偏好设置"|"系统设置") icon_result=":system_preferences:" ;;
    "App Store") icon_result=":app_store:" ;;
    "Activity Monitor"|"活动监视器") icon_result=":activity_monitor:" ;;
    "Raycast") icon_result=":raycast:" ;;
    "Alfred") icon_result=":alfred:" ;;
    "1Password") icon_result=":1password:" ;;
    "Bitwarden") icon_result=":bitwarden:" ;;
    "Docker Desktop"|"Docker") icon_result=":docker:" ;;
    "GitHub Desktop") icon_result=":github:" ;;
    "Fork") icon_result=":fork:" ;;
    "Tower") icon_result=":tower:" ;;
    "TablePlus") icon_result=":tableplus:" ;;
    "Sequel Pro") icon_result=":sequel_pro:" ;;
    "MongoDB Compass") icon_result=":mongodb:" ;;
    "Postman") icon_result=":postman:" ;;
    "Insomnia") icon_result=":insomnia:" ;;
    "Linear") icon_result=":linear:" ;;
    "CleanMyMac X") icon_result=":cleanmymac:" ;;
    "CleanShot X") icon_result=":cleanshot_x:" ;;
    "Transmit") icon_result=":transmit:" ;;
    "Cyberduck") icon_result=":cyberduck:" ;;
    "FileZilla") icon_result=":filezilla:" ;;
    "VMware Fusion") icon_result=":vmware_fusion:" ;;
    "Parallels Desktop") icon_result=":parallels:" ;;
    "VirtualBox") icon_result=":virtualbox:" ;;
    "Microsoft Word") icon_result=":microsoft_word:" ;;
    "Microsoft Excel") icon_result=":microsoft_excel:" ;;
    "Microsoft PowerPoint") icon_result=":microsoft_powerpoint:" ;;
    "Microsoft Outlook") icon_result=":microsoft_outlook:" ;;
    "Microsoft OneNote") icon_result=":microsoft_onenote:" ;;
    "Numbers") icon_result=":numbers:" ;;
    "Keynote") icon_result=":keynote:" ;;
    "Pages") icon_result=":pages:" ;;
    "News"|"新闻") icon_result=":news:" ;;
    "Stocks"|"股市") icon_result=":stocks:" ;;
    "Home"|"家庭") icon_result=":home:" ;;
    "Maps"|"地图") icon_result=":maps:" ;;
    "Weather"|"天气") icon_result=":weather:" ;;
    "Clock"|"时钟") icon_result=":clock:" ;;
    "Calculator"|"计算器") icon_result=":calculator:" ;;
    "Books"|"图书") icon_result=":books:" ;;
    "Contacts"|"通讯录") icon_result=":contacts:" ;;
    "Freeform") icon_result=":freeform:" ;;
    "Voice Memos"|"语音备忘录") icon_result=":voice_memos:" ;;
    "Screen Sharing"|"屏幕共享") icon_result=":screen_sharing:" ;;
    "TextEdit"|"文本编辑") icon_result=":textedit:" ;;
    *) icon_result=":default:" ;;
  esac

  echo "$icon_result"
}

__icon_map "$1"
