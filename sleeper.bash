#!/bin/bash

# Chinachuγで録画が終わったらシャットダウンするためのスクリプト
# crontabに登録して5分間隔くらいで動かしておけばほどほどのタイミングで落ちてくれるはず。
# 3-58/5 * * * * /home/ubuntu/poff/sleeper.bash >>//home/ubuntu/poff/s.log
# jq1.5必要。1.3は数値型の解釈でまずかったのでNG、1.4は試してないから不明。
# 同マシン上で録画と別に作業したい場合は別セッション開いて、(while :; do shutdown -c; sleep 30; done;)　こんな感じにしておけばいいあ

: <<"#__COMMENT__"
0.録画中かどうかチェック
  0.1.録画中ならシャットダウンしないで処理終了
1.最も近い未来の録画開示時刻を取得
2.そのn分前に起動するようにACPIをセット
  2.1.n分前が過去であればACPIセットしないで処理終了
3.シャットダウン
#__COMMENT__

# CONST
# 何分前に起動するか
WAKEUP_MARGIN=10
# シャットダウンコマンドの猶予時間
SHUTDOWN_MARGIN=1

# 0
# 録画中なら番組情報が入るので10byte*録画数になるはず
# 録画中でなければ0byte
RECSTATE=$(curl -s 'http://localhost:20772/api/recording.json' | jq -r '.[].id')

if [[ ${#RECSTATE} > 0 ]]; then
    echo 録画中なのでシャットダウンしない
    exit 0
fi

# 1
# 最も近い未来の録画開示時刻を取得
NEXTTIME=$(curl -s 'http://localhost:20772/api/reserves.json' | jq -r '.[].start' | sort -n | head -1 | rev | cut -c4- | rev)

if [[ $(date +%s) > $((${NEXTTIME} - 60 * ${WAKEUP_MARGIN} - 3600 )) ]]; then
    # 頻繁にON/OFFするとディスクに負荷がかかりそうなので、1時間以内に再起動が必要になる場合はシャットダウンしない
    echo 再起動予定時刻を過ぎているのでシャットダウンしない
    exit 0
fi

# 2
# 設定済みだとリソースビジーで引っかかることがあるのでいったんクリアしてから書き込み
sudo sh -c "echo 0 >/sys/class/rtc/rtc0/wakealarm"
echo $((${NEXTTIME} - 60 * ${WAKEUP_MARGIN})) | sudo tee -a /sys/class/rtc/rtc0/wakealarm

# 設定後のrtcを確認する用のコマンド
# cat /proc/driver/rtc

# 3
# shutdown -cできるように余裕を見て落とす
sudo shutdown -h ${SHUTDOWN_MARGIN}

