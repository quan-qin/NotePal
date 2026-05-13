# NotePal macOS

这里是 NotePal 的 macOS Swift Package。

NotePal 是一个轻量的桌面陪伴工具，面向随手记录、健康提醒和桌面福伴三个场景。

## 三点亮点

- 灵感：随笔或画记。
- 养生：准时健康提醒。
- 福伴：好运常驻桌面。

## 构建并运行

```sh
swift build
swift run NotePal
```

## 打包本地应用

```sh
Scripts/build_app.sh
```

输出文件：

```text
build/NotePal.app
build/NotePal-mac-arm64.zip
```

当前 beta 包使用 ad-hoc 签名，尚未通过 Apple notarization。公开分发时，用户首次打开可能会看到 macOS 安全提示。
