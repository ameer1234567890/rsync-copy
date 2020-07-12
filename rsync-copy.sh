#!/bin/sh

# NOTES:
# rsync binaries for Windows are compiled for Cygwin, and so
# requires paths starting with "/cygdrive/c/", "/cygdrive/d/", etc...
# 
# rsync binaries which are compiled for Cygwin, needs to be run
# on Windows console, rather than Git bash, etc...

RSYNC_LOCATION="rsync://nas1.lan/usb1/aria2/"

# shellcheck disable=SC2039
if [ "$OSTYPE" = "cygwin" ] \
|| [ "$OSTYPE" = "msys" ]; then
  # This is cygwin or Git bash on Windows
  DEST_DIRECTORY="$(echo "$USERPROFILE"/Downloads | sed 's/\\/\//g; s/://g; s/^/\/cygdrive\//g')"
elif [ "$(echo "$PREFIX" | grep -F "com.termux")" != "" ]; then
  # This is Termux on Android
  DEST_DIRECTORY="$HOME"
elif [ "$(uname)" = "Linux" ]; then
  # This is Linux
  DEST_DIRECTORY="$HOME"
else
  # Unable to identify OS
  DEST_DIRECTORY="."
fi


cleanup() {
  rm temp.txt 2>/dev/null
  exit
}


OFS=$IFS
IFS='
'
i=0
rm temp.txt 2>/dev/null
for file in $(rsync $RSYNC_LOCATION); do
  if [ "$(echo "$file" | awk '{print substr($0, index($0,$5))}')" != "." ] \
  && [ "$(echo "$file" | tail -c 7)" != ".aria2" ]; then
    i=$((i + 1))
    size="$(echo "$file" | awk '{print $2}' | tr -d ',')"
    if [ "$size" -lt 1024 ]; then
      size="$size B"
    elif [ "$size" -lt 1048576 ]; then
      size="$(awk -v s="$size" 'BEGIN { print (s / 1024) }')"
      size="$(printf "%0.2f\n" "$size") KB"
    elif [ "$size" -lt 1073741824 ]; then
      size="$(awk -v s="$size" 'BEGIN { print (s / 1048576) }')"
      size="$(printf "%0.2f\n" "$size") MB"
    else
      size="$(awk -v s="$size" 'BEGIN { print (s / 1073741824) }')"
      size="$(printf "%0.2f\n" "$size") GB"
    fi
    if [ "$(echo "$file" | awk '{print substr($1, 1, 1)}')" = "d" ]; then
      size="DIRECTORY"
    fi
    file="$(echo "$file" | awk '{print substr($0, index($0,$5))}')"
    echo "$file" >> temp.txt
    echo "[$i] $file [$size]"
  fi
done
IFS=$OFS
echo "[0] Exit"

while true; do
  printf "Select option: "
  read -r opt
  if [ "$opt" -eq "$opt" ] 2>/dev/null \
  && [ "$opt" -gt -1 ] 2>/dev/null \
  && [ "$opt" -le "$i" ] 2>/dev/null; then
    break
  fi
done

if [ "$opt" -eq 0 ]; then
  cleanup
fi

remote_file="$RSYNC_LOCATION$(sed -n "${opt}p" temp.txt)"
rm temp.txt 2>/dev/null

while true; do
  printf "Please specify destination directory (%s): " "$DEST_DIRECTORY"
  read -r opt
  if [ -d "$opt" ] 2>/dev/null \
  || [ "$opt" = "" ]; then
    break
  fi
done

if [ "$opt" != "" ]; then
  DEST_DIRECTORY="$opt"
fi

echo "Starting file copy..."
echo "======================================================"

# shellcheck disable=SC2039
if [ "$OSTYPE" = "cygwin" ] \
|| [ "$OSTYPE" = "msys" ]; then
  echo "@echo off" > temp.bat
  echo "chcp 65001 > NUL" >> temp.bat
  echo rsync --progress -h --partial \""$remote_file"\" \""$DEST_DIRECTORY"\" >> temp.bat
  cmd "/C temp.bat"
  status="$?"
  rm temp.bat 2>/dev/null
  # shellcheck disable=SC2129
  if [ "$status" = 0 ]; then
    echo "[void] [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms');" > temp.ps1
    echo "\$objNotifyIcon=New-Object System.Windows.Forms.NotifyIcon;" >> temp.ps1
    echo "\$objNotifyIcon.BalloonTipText='File copied successfully!';" >> temp.ps1
    echo "\$objNotifyIcon.Icon=[system.drawing.systemicons]::'Information';" >> temp.ps1
    echo "\$objNotifyIcon.BalloonTipTitle='rsync-copy';" >> temp.ps1
    echo "\$objNotifyIcon.BalloonTipIcon='Info';" >> temp.ps1
    echo "\$objNotifyIcon.Visible=\$True;" >> temp.ps1
    echo "\$objNotifyIcon.ShowBalloonTip(5000);" >> temp.ps1
    powershell -File temp.ps1
  else
    echo "[void] [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms');" > temp.ps1
    echo "\$objNotifyIcon=New-Object System.Windows.Forms.NotifyIcon;" >> temp.ps1
    echo "\$objNotifyIcon.BalloonTipText='An error occured during file copy! Please try again later!';" >> temp.ps1
    echo "\$objNotifyIcon.Icon=[system.drawing.systemicons]::'Error';" >> temp.ps1
    echo "\$objNotifyIcon.BalloonTipTitle='rsync-copy';" >> temp.ps1
    echo "\$objNotifyIcon.BalloonTipIcon='Error';" >> temp.ps1
    echo "\$objNotifyIcon.Visible=\$True;" >> temp.ps1
    echo "\$objNotifyIcon.ShowBalloonTip(5000);" >> temp.ps1
    powershell -File temp.ps1
  fi
  rm temp.ps1
elif [ "$(echo "$PREFIX" | grep -F "com.termux")" != "" ]; then
  sh -c "rsync --progress -h --partial \"""$remote_file""\" \"""$DEST_DIRECTORY""\""
  status="$?"
  if [ "$status" = 0 ]; then
    termux-notification --title 'rsync-copy' --content "File copied successfully!"
  else
    termux-notification --title 'rsync-copy' --content "An error occured during file copy! Please try again later!"
  fi
else
  sh -c "rsync --progress -h --partial \"""$remote_file""\" \"""$DEST_DIRECTORY""\""
fi

echo "======================================================"

sh "$0"
