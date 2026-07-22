# Translatora

一款 macOS 上的划词翻译 + 个人词典应用：在任意应用中选中文本，按下快捷键即可唤起**翻译浮窗**，由 DeepSeek 大模型完成翻译并附例句；翻译结果可一键收藏，沉淀为**应用首页**里的**词汇列表**。

## 功能特性

### 划词翻译 / 翻译浮窗

- 全局快捷键（默认 `⇧⌘T`，可在设置中自定义录制）随时唤起翻译浮窗
- 自动读取前台应用中的选中文本并即时翻译，也支持手动输入
- 浮窗不打断当前工作流，用完即走

### AI 翻译引擎

- 接入 DeepSeek 大模型 API，翻译结果附带 1–2 条例句，帮助理解语境
- 可选模型：**DeepSeek V4 Flash**（默认，更快）/ **V4 Pro**（更强）
- 支持 8 种语言互译：英语、简体中文、繁体中文、日语、韩语、法语、德语、西班牙语，支持源/目标语言一键互换

### 词汇列表（个人词典）

- 翻译结果一键收藏，在应用首页按「今天 / 昨天 / 日期」分组展示
- 详情视图支持前后翻页浏览、编辑笔记、删除条目
- 数据保存在本地（`~/Library/Application Support/Translatora/dictionary.json`），无需账号

### 外观与个性化

- 跟随系统 / 浅色 / 深色三种外观模式
- 采用 macOS 26 Liquid Glass 风格界面

## 截图

| 应用首页（词汇列表） | 翻译浮窗 | 设置 |
| :---: | :---: | :---: |
| ![应用首页](docs/screenshots/home.png) | ![翻译浮窗](docs/screenshots/translation-panel.png) | ![设置](docs/screenshots/settings.png) |

## 使用准备

1. 首次使用需在「设置」中填入 DeepSeek API Key（可在 [DeepSeek 开放平台](https://platform.deepseek.com) 申请），并用「连接测试」验证可用性。
2. 划词翻译依赖 macOS 辅助功能权限来读取选中文本，首次唤起翻译浮窗时请按引导在「系统设置 → 隐私与安全性 → 辅助功能」中授权。

## 技术栈

- SwiftUI + Combine，纯系统框架（AppKit / Carbon / ApplicationServices），无第三方依赖
- 全局快捷键基于 Carbon HotKey API
- 最低系统版本：**macOS 26.0**

## 构建与测试

```bash
# 用 Xcode 打开
open Translatora.xcodeproj

# 命令行构建
xcodebuild -project Translatora.xcodeproj -scheme Translatora build

# 运行测试
xcodebuild -project Translatora.xcodeproj -scheme Translatora test
```

## 项目结构

```
Translatora/
├── Models/        # 数据模型（翻译、词典条目、外观、DeepSeek 配置等）
├── Services/      # 翻译服务、词典存储、快捷键监听、选中文本读取等
├── Views/         # 应用首页、翻译浮窗、设置等 SwiftUI 视图
└── Assets.xcassets
TranslatoraTests/  # 单元测试
docs/              # 命名约定、问题修复记录等文档
```

术语约定：产品文档中统一使用「应用首页」「词汇列表」「翻译浮窗」，详见 [docs/naming-conventions.md](docs/naming-conventions.md)。
