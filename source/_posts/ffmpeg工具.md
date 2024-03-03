---
title: ffmpeg工具
date: 2024-01-24 22:58:09
category_bar: true
categories: Linux
---

我上一次使用这个工具是转换视频的格式，后来大概了解了一下这个工具，在音视频领域属于底层基石的存在，该作者也是一名传奇人物。

我目前接触下来使用的功能为

- 转换视频格式

- 视频配字幕

1 转换视频格式
---

```shell
ffmpeg -i input.webm output.mp4
```

2 视频合并字幕
---

```shell
ffmpeg -i Ch16.mkv -vf "subtitles=Ch16.vtt" -c:a copy Ch16.mp4
```

将视频Ch16.mkv和字幕Ch16.vtt合并为新的视频Ch16.mp4