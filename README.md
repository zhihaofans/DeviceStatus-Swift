# DeviceStatus

多平台 SwiftUI App，用于查看设备系统信息，并作为测试自研开源库的宿主工程。

## 支持平台

| 平台 | 最低版本 | Bundle ID |
| --- | --- | --- |
| iOS（iPhone / iPad） | 26.0 | `me.zzhhoo.DeviceStatus` |
| macOS | 26.0 | `me.zzhhoo.DeviceStatus` |
| watchOS | 26.0 | `me.zzhhoo.DeviceStatus` |

三平台由**同一个 target**（Supported Destinations）产出，不是三个独立 target。
visionOS 已从 `SUPPORTED_PLATFORMS` / `TARGETED_DEVICE_FAMILY` 中移除。

## 工程结构

```
DeviceStatus.xcodeproj
  xcshareddata/xcschemes/DeviceStatus.xcscheme   共享 scheme（CI 与命令行归档依赖它）
DeviceStatus/
  DeviceStatusApp.swift
  ContentView.swift                              主界面：分组列表 + 搜索 + 点击复制 + 下拉刷新
  Model/DeviceInfo.swift                         分组 / 条目数据模型
  Service/DeviceInfoProvider.swift               设备信息采集
  Service/SystemClipboard.swift                  剪贴板薄封装（watchOS 上没有剪贴板）
  PrivacyInfo.xcprivacy                          隐私清单（Required Reason API）
  Assets.xcassets/AppIcon.appiconset/            iOS + macOS + watchOS 图标（当前为占位图）
DeviceStatusTests/
  SwiftUtilsIntegrationTests.swift               验证 SwiftUtils 在三个平台的集成行为
  DeviceInfoProviderTests.swift                  验证采集层输出一定可展示
Scripts/
  generate-appicons.py                           重新生成占位图标
```

> 工程使用 Xcode 16+ 的**文件夹同步组**（`PBXFileSystemSynchronizedRootGroup`）：
> 往 `DeviceStatus/` 里新增 `.swift`、`.xcprivacy`、asset catalog 等文件会自动进入 target，
> 不需要手改 `project.pbxproj`。新增 **target** 仍然要改工程文件。

## 功能

| 功能 | 说明 |
| --- | --- |
| 系统信息 | 系统版本、`kern.osversion` 构建号、平台、开机时长、语言、地区、时区 |
| 硬件信息 | 设备名称、设备型号、CPU 核心、物理内存 |
| 存储 | 总容量 / 已用 / 可用 / 使用率（`URL.volume*CapacityKey`） |
| 电池 | 电量、充电状态（走 `DeviceUtil`，读前先开电池监控） |
| 屏幕 | 亮度、缩放、深色模式 |
| 网络 | 连接类型，异步经 `NetworkUtil` 取得，不阻塞其它分组 |
| 应用 | 版本、构建号、Bundle ID、最低系统 |
| 搜索 | 按标题或值过滤，命中为空的分组整组隐藏 |
| 复制 | 点条目复制单条；工具栏按钮复制**当前可见**内容（搜索后只复制命中项） |
| 外观刷新 | 切换白天/深夜时自动重采一遍本地信息，「深色模式」一行立即更新（不重取网络，它与外观无关） |

> 存储与开机时长分别命中 `NSPrivacyAccessedAPICategoryDiskSpace` 与
> `NSPrivacyAccessedAPICategorySystemBootTime`，隐私清单里已经声明。

## 构建

```bash
cd /path/to/DeviceStatus

# iOS 模拟器
xcodebuild -scheme DeviceStatus \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build

# macOS
xcodebuild -scheme DeviceStatus -destination 'platform=macOS' build

# watchOS 模拟器
xcodebuild -scheme DeviceStatus \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=26.2' build
```

部署目标是 26.0，所以只能选 **iOS ≥ 26.0 / watchOS ≥ 26.0** 的模拟器或真机。
（本机若只装了 iOS 18.4 的 runtime，那个模拟器选不上。）

## 已经配好的上架相关项

| 设置 | 值 | 作用 |
| --- | --- | --- |
| `SUPPORTED_PLATFORMS` | `iphoneos iphonesimulator macosx watchos watchsimulator` | 三平台 |
| `TARGETED_DEVICE_FAMILY` | `1,2,4` | iPhone / iPad / Apple Watch |
| `INFOPLIST_KEY_WKApplication` | `YES` | 让产物被识别为 watchOS App |
| `INFOPLIST_KEY_LSApplicationCategoryType` | `public.app-category.utilities` | macOS 上架强校验项 |
| `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption` | `NO` | 免去每次上传回答出口合规 |
| `ENABLE_APP_SANDBOX` / `ENABLE_HARDENED_RUNTIME` | `YES` | Mac App Store 必须 |
| `SWIFT_VERSION` | `6.0` | Swift 6 语言模式（严格并发） |
| `PrivacyInfo.xcprivacy` | 已加入 | 四个 Required Reason API 类别 |

### 隐私清单里声明的 API 类别

| 类别 | 理由码 | 对应场景 |
| --- | --- | --- |
| `NSPrivacyAccessedAPICategorySystemBootTime` | `35F9.1` | `ProcessInfo.systemUptime`，显示开机时长 |
| `NSPrivacyAccessedAPICategoryDiskSpace` | `85F4.1` | 磁盘容量信息展示 |
| `NSPrivacyAccessedAPICategoryFileTimestamp` | `C617.1` | 读取文件/缓存时间戳 |
| `NSPrivacyAccessedAPICategoryUserDefaults` | `CA92.1` | 保存用户偏好设置 |

如果后续用到了别的类别（例如 `NSPrivacyAccessedAPICategoryActiveKeyboards`），
必须在 `DeviceStatus/PrivacyInfo.xcprivacy` 里补上，否则 App Store Connect 会拦（ITMS-91053）。
反之，某个 API 最终没用到，删掉对应条目更严谨。

## 上架前仍需人工处理

1. **正式 App 图标**。当前 `AppIcon.appiconset` 里的 PNG 是 `Scripts/generate-appicons.py`
   生成的占位图。替换时保持文件名不变即可；也可以改用 Xcode 27 的 Icon Composer（`.icon`），
   但注意：**actool 目前不把 asset catalog 里的 `.icon` 当 app icon set**，
   实测会报 `None of the input catalogs contained a matching ... app icon set named "AppIcon"`，
   所以换用 Icon Composer 时要同时调整 `ASSETCATALOG_COMPILER_APPICON_NAME` 的指向方式。
2. **签名**。本机目前只有 `Apple Development` 证书，没有 `Apple Distribution`。
   上传 App Store 需要已付费的 Apple Developer Program 账号，
   在 Xcode 里开启 Automatically manage signing 后会自动生成 Distribution 证书与描述文件。
   Team ID 目前是 `9DU6DRLH3R`。
3. **App Store Connect**：注册 `me.zzhhoo.DeviceStatus`，建立 app 记录，
   准备截图（iOS / macOS / watchOS 各一套）、隐私政策 URL、App 隐私标签。
4. **本地化**：`knownRegions` 目前只有 `en` / `Base`，没有 `zh-Hans`。
   面向国内用户建议补 `zh-Hans` 的 `InfoPlist.strings`（可把显示名设成中文）与 String Catalog。
5. **版本号**：`MARKETING_VERSION` 与 `CURRENT_PROJECT_VERSION` 每次上传必须递增且唯一，
   建议接 `agvtool` 或 CI 自动 bump。

## 平台限制与已知问题

### 1. watchOS：单 target 只能做 watch-only（已解决并配置）

原先装不上手表，报 `Missing WKCompanionAppBundleIdentifier key`。
在手表模拟器上把两种修法都实测了一遍：

| 方案 | 结果 |
| --- | --- |
| `WKWatchOnly = YES` | ✅ 安装成功、启动成功 |
| `WKCompanionAppBundleIdentifier = me.zzhhoo.DeviceStatus`（自引用） | ❌ 被拒 |

自引用被拒的原文：

```
This app's bundle identifier does not start with its parent app's bundle
identifier followed by a dot ('.') character. ... this app indicates that
its bundle identifier is "me.zzhhoo.DeviceStatus".
```

**关键结论**：系统要求 companion 的 bundle id 必须是 `<父 id>.xxx`，而单 target 只能产出一个
bundle id，**所以单 target 多平台做不出 companion watch app，只能做 watch-only**。
这正是 Apple 报错里给的第二条出路。

已按 SDK 限定配置（限定是为了不让这些键污染 iOS / macOS 的 Info.plist）：

```
"INFOPLIST_KEY_WKApplication[sdk=watchos*]" = YES;
"INFOPLIST_KEY_WKApplication[sdk=watchsimulator*]" = YES;
"INFOPLIST_KEY_WKWatchOnly[sdk=watchos*]" = YES;
"INFOPLIST_KEY_WKWatchOnly[sdk=watchsimulator*]" = YES;
```

**产品层面的后果**：手表上是独立 App，只能看手表自己的信息，
拿不到配对 iPhone 的电量、存储等。如果以后想做「在手表上看 iPhone 的状态」，
必须拆成独立 watchOS target（bundle id 用 `me.zzhhoo.DeviceStatus.watchkitapp`、
`TARGETED_DEVICE_FAMILY = 4`、`SKIP_INSTALL = YES`、
`WKCompanionAppBundleIdentifier = me.zzhhoo.DeviceStatus`、再嵌进 iOS App），
用 WatchConnectivity 同步数据。

**上架待确认**：watch-only 的 watchOS 产物与 iOS / macOS 共用同一个 bundle id，
归档上传时需要确认 App Store Connect 接受这种「一个 app 记录、多平台产物」的提交方式。

### 2. Swift 6 默认 MainActor 隔离 + 回调式 API = 运行时崩溃

工程开了 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`。凡是把闭包传给
**在后台队列回调**的 API，闭包会隐式继承主线程隔离，然后在 Swift 6 运行时的
隔离检查处直接 trap：

```
dispatch_assert_queue_fail
  ← _swift_task_checkIsolatedSwift
  ← closure #1 in DeviceInfoProvider.networkTypeLabel()
  ← NetworkUtil.swift:46        (com.apple.root.background-qos)
```

**这是运行时崩溃，不是编译错误**，编译器不会提醒。当前绕法是把这个函数标成
`nonisolated`（见 `DeviceInfoProvider.networkTypeLabel()` 的注释）。

`NetworkUtil.getNetworkType(callback:fail:)`、`HttpUtil`、`AuthUtil` 这类回调 API
都有同样的风险。**根治在库这边**：把回调参数声明成 `@escaping @Sendable`
（例如 `callback: @escaping @Sendable (NetworkType?) -> Void`），
调用方就不会再隐式继承 actor 隔离，同时也把"回调在哪个队列"变成类型上可见的约定。

### 3. `AppUtil.isDarkColorMode()` 的 macOS 分支（已修复，但仍无测试）

0.0.24 及以前的实现：

```swift
public func isDarkColorMode() -> Bool {
#if os(watchOS)
    return true       // watchOS 界面恒为深色，符合实际
#elseif os(macOS)
    return false      // ← 硬编码，深色模式下也返回 false
#else
    return UITraitCollection.current.userInterfaceStyle == .dark
#endif
}
```

- **macOS：确认是缺陷**（源码无分支，永远返回 false）。
- **iOS：实测是对的**。模拟器切成深色后跑临时探针，返回 `true`。
- **watchOS：恒为 true，符合实际**。

SwiftUtils **0.0.25 已修复**（`df31ffe`）：

```swift
#elseif os(macOS)
    return NSApp?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
```

所以本工程「深色模式」一行已改回直接调用 `AppUtil().isDarkColorMode()`，
视图侧只用 `\.colorScheme` 当刷新触发器——外观一变就重采一遍，两者职责分开。

**注意两点**：

1. `isDarkColorMode()` 在 SwiftUtils 仓库里**没有任何单元测试**
   （`git grep isDarkColorMode 0.0.25 -- Tests/` 为空）。App 这边只能钉住
   「watchOS 恒为「是」」这个跨平台契约，其余平台的取值依赖运行环境，测不了固定结果。
2. 新实现用了 `NSApp?`，可选链意味着 **`NSApp` 为 nil 时（非 GUI 进程，比如 SwiftPM 测试进程）
   会静默返回 `false`**，看起来仍像"永远是浅色"。如果要让它在任何上下文都可靠，
   可以退回 `NSAppearance.currentDrawing()` 或加一个明确的失败信号。

## 已知无害警告

macOS 构建会稳定输出一条：

```
AppIcon.appiconset/[...][AppIcon-watch-marketing-1024.png]:
warning: The app icon set "AppIcon" has an unassigned child.
```

原因是三平台共用一个 asset catalog：`watch-marketing` 1024x1024 是 watchOS 需要的 slot，
但 macOS 的 actool 不认识它。iOS 与 watchOS 构建都是零警告，构建结果不受影响。
拆成平台各自的 asset catalog 可以消掉这条警告，代价是 `ASSETCATALOG_COMPILER_APPICON_NAME`
要按 SDK 分别配置，收益不大。

## 重新生成占位图标

```bash
python3 Scripts/generate-appicons.py
```

依赖 Pillow。脚本会重写 `AppIcon.appiconset/Contents.json` 并清掉不再需要的旧 PNG。
