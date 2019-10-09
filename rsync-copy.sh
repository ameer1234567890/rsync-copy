#!/bin/sh

# NOTES:
# rsync binaries for Windows are compiled for Cygwin, and so
# requires paths starting with "/cygwin/c/", "/cygwin/d/", etc...
# rsync binaries which are compiled for Cygwin, needs to be run
# on Windows console, rather than Git bash, etc...

RSYNC_LOCATION="rsync://192.168.100.44/usb1/aria2/"

# shellcheck disable=SC2039
if [ "$OSTYPE" = "cygwin" ] || [ "$OSTYPE" = "msys" ]; then
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
  if [ "$(echo "$file" | awk '{print substr($0, index($0,$5))}')" != "." ]; then
    i=$((i + 1))
    file="$(echo "$file" | awk '{print substr($0, index($0,$5))}')"
    echo "$file" >> temp.txt
    echo "[$i] $file"
  fi
done

i=$((i + 1))
echo "[$i] Exit"
IFS=$OFS

while true; do
  printf "Select option: "
  read -r opt
  if [ "$opt" -eq "$opt" ] 2>/dev/null && [ "$opt" -gt 0 ] 2>/dev/null && [ "$opt" -le "$i" ] 2>/dev/null; then
    break
  fi
done

if [ "$opt" -eq "$i" ]; then
  cleanup
fi

remote_file="$RSYNC_LOCATION$(sed -n "${opt}p" temp.txt)"
rm temp.txt 2>/dev/null

while true; do
  printf "Please specify destination directory (%s): " "$DEST_DIRECTORY"
  read -r opt
  if [ -d "$opt" ] 2>/dev/null || [ "$opt" = "" ]; then
    break
  fi
done

if [ "$opt" != "" ]; then
  DEST_DIRECTORY="$opt"
fi

echo "Starting file copy..."
echo "======================================================"

# shellcheck disable=SC2039
if [ "$OSTYPE" = "cygwin" ] || [ "$OSTYPE" = "msys" ]; then
  echo "@echo off" > temp.bat
  echo rsync --progress -h --partial \""$remote_file"\" \""$DEST_DIRECTORY"\" >> temp.bat
  cmd "/C temp.bat"
  status="$?"
  rm temp.bat 2>/dev/null
  if [ "$status" = 0 ]; then
    echo "@echo off" > temp.bat
    echo "powershell -Command \"[void] [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); \$objNotifyIcon=New-Object System.Windows.Forms.NotifyIcon; \$objNotifyIcon.BalloonTipText='File copied successfully!'; \$objNotifyIcon.Icon=[system.drawing.systemicons]::'Information'; \$objNotifyIcon.BalloonTipTitle='rsync-copy'; \$objNotifyIcon.BalloonTipIcon='Info'; \$objNotifyIcon.Visible=\$True; \$objNotifyIcon.ShowBalloonTip(5000);\"" >> temp.bat
    cmd "/C temp.bat"
    rm temp.bat
  else
    echo "@echo off" > temp.bat
    echo "powershell -Command \"[void] [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); \$objNotifyIcon=New-Object System.Windows.Forms.NotifyIcon; \$objNotifyIcon.BalloonTipText='An error occured during file copy! Please try again later!'; \$objNotifyIcon.Icon=[system.drawing.systemicons]::'Error'; \$objNotifyIcon.BalloonTipTitle='rsync-copy'; \$objNotifyIcon.BalloonTipIcon='Error'; \$objNotifyIcon.Visible=\$True; \$objNotifyIcon.ShowBalloonTip(5000);\"" >> temp.bat
    cmd "/C temp.bat"
    rm temp.bat 2>/dev/null
  fi
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
