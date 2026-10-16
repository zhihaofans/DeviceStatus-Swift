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

## 已知问题

### 1. watchOS 能编译但装不上手表（未解决，阻塞上架）

`xcodebuild -destination 'platform=watchOS Simulator,...' test` 会失败，直接装也会被拒：

```
me.zzhhoo.DeviceStatus: Missing WKCompanionAppBundleIdentifier key
in WatchKit 2.0 app's Info.plist
```

单 target 多平台产出的 watchOS 产物被系统当作 **WatchKit 2.0 companion app**，
必须声明它的 iPhone 宿主是谁。两条出路：

- **加键**：给 watchOS 侧补 `INFOPLIST_KEY_WKCompanionAppBundleIdentifier[sdk=watchos*]`，
  指向 iOS 的 bundle id。改动最小，但"自己是自己的 companion"这种自引用是否被 App Store 接受，
  没有把握，需要归档后验证。
- **拆成独立 watchOS target**（推荐）：bundle id 用 `me.zzhhoo.DeviceStatus.watchkitapp`，
  `TARGETED_DEVICE_FAMILY = 4`、`SKIP_INSTALL = YES`，再用
  `INFOPLIST_KEY_WKCompanionAppBundleIdentifier = me.zzhhoo.DeviceStatus` 指回 iOS App，
  并嵌入 iOS App。这是 Xcode 自己 watchOS 模板的做法，是确定可上架的形态。

iOS 与 macOS 不受影响，均已实机验证通过。

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
