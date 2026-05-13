# NotePal

NotePal 是一个轻量的 macOS 桌面陪伴工具，用来快速记录灵感、管理待办、接收健康提醒，并让一个好运福伴常驻桌面。它不需要账号、云同步、遥测或额外后台服务，数据只保存在本机。

## 三点亮点

- 灵感：随笔或画记。
- 养生：准时健康提醒。
- 福伴：好运常驻桌面。

## 功能

- 桌面悬浮福伴，点击即可打开随笔、画记、待办和养生提醒。
- 随笔和画记相互隔离，新增、编辑、删除互不影响。
- 随笔支持本地图片粘贴。
- 待办支持到期提醒气泡。
- 养生提醒独立管理，不混入待办列表。
- 内置多个福伴形象，并支持特殊形象解锁。
- 支持主题菜单、静默闲聊、动画开关和菜单控制。
- 仅使用本地 JSON 持久化。

## 下载

打开最新 GitHub Release，下载：

```text
NotePal-mac-arm64.zip
```

解压后，将 `NotePal.app` 移动到 `/Applications`。

当前 beta 版本使用 ad-hoc 签名，尚未通过 Apple notarization。首次启动时，macOS 可能会拦截应用。如果你信任该构建，可以在 Finder 中按住 Control 点击 `NotePal.app`，选择“打开”，再确认“打开”。

## 系统要求

- macOS 13 或更新版本
- 当前公开下载包为 Apple Silicon `arm64` 构建

## 从源码构建

构建并运行 Swift Package：

```sh
cd NotePal
swift build
swift run NotePal
```

生成本地 `.app` 包：

```sh
cd NotePal
Scripts/build_app.sh
```

构建产物位于：

```text
NotePal/build/NotePal.app
NotePal/build/NotePal-mac-arm64.zip
```

## 本地数据

NotePal 将用户数据保存在本机：

```text
~/Library/Application Support/NotePal/notepal-data.json
```

首次启动时，NotePal 会尝试导入兼容的旧版本地数据，让已有随笔、画记和待办继续可用。

## 仓库结构

```text
NotePal/
  Sources/NotePal/      macOS Swift 应用源码
  Scripts/              本地构建和素材处理脚本
.github/workflows/      GitHub Actions 发布流程
```
