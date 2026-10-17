//
//  DeviceInfoProvider.swift
//  DeviceStatus
//
//  采集设备信息。尽量走 SwiftUtils 的 DeviceUtil / AppUtil，
//  库没覆盖的部分（构建号、内存、存储、语言时区）用系统 API 补齐。
//

import Foundation
import SwiftUtils

@MainActor
enum DeviceInfoProvider {

    // MARK: - 采集

    /// 同步就能拿到的分组。网络类型是异步的，见 `loadNetworkGroup()`。
    ///
    /// 深色模式判定走 `AppUtil().isDarkColorMode()`。SwiftUtils 0.0.24 及以前 macOS 分支
    /// 硬编码返回 false，当时这里临时改用了 SwiftUI 的 `colorScheme`；
    /// 0.0.25 修好之后（`NSApp?.effectiveAppearance...`）就改回走库，
    /// 否则这个集成工程就测不到那个 API 了。
    /// 视图侧仍然用 `\.colorScheme` 当刷新触发器——外观一变就重采一遍。
    static func snapshot(displayScale: CGFloat) -> [DeviceInfoGroup] {
        [
            systemGroup(),
            hardwareGroup(),
            storageGroup(),
            batteryGroup(),
            screenGroup(displayScale: displayScale),
            appGroup(),
        ]
    }

    /// 网络类型需要 NWPathMonitor 回调，单独异步取。取不到时按「无连接」展示，不阻塞其它分组。
    static func loadNetworkGroup() async -> DeviceInfoGroup {
        let label = await networkTypeLabel()
        return DeviceInfoGroup(
            title: "网络",
            symbol: "wifi",
            items: [DeviceInfoItem(title: "连接类型", value: label)]
        )
    }

    /// 把分组列表拍平成纯文本，供「复制全部」使用。
    static func plainText(_ groups: [DeviceInfoGroup]) -> String {
        groups
            .map { group in
                ([group.title] + group.items.map { "  \($0.title): \($0.value)" })
                    .joined(separator: "\n")
            }
            .joined(separator: "\n\n")
    }

    // MARK: - 分组

    private static func systemGroup() -> DeviceInfoGroup {
        let locale = Locale.current
        return DeviceInfoGroup(
            title: "系统",
            symbol: "gearshape",
            items: [
                DeviceInfoItem(title: "系统版本", value: DeviceUtil().getSystemVersion()),
                DeviceInfoItem(title: "系统构建", value: systemBuildNumber()),
                DeviceInfoItem(title: "平台", value: platformName()),
                DeviceInfoItem(
                    title: "开机时长",
                    value: formattedUptime(ProcessInfo.processInfo.systemUptime)
                ),
                DeviceInfoItem(
                    title: "语言",
                    value: locale.language.languageCode?.identifier ?? locale.identifier
                ),
                DeviceInfoItem(title: "地区", value: locale.region?.identifier ?? "未知"),
                DeviceInfoItem(title: "时区", value: TimeZone.current.identifier),
            ]
        )
    }

    private static func hardwareGroup() -> DeviceInfoGroup {
        let device = DeviceUtil()
        let processInfo = ProcessInfo.processInfo
        return DeviceInfoGroup(
            title: "硬件",
            symbol: "cpu",
            items: [
                DeviceInfoItem(title: "设备名称", value: device.getDeviceName()),
                DeviceInfoItem(title: "设备型号", value: device.getDeviceModel()),
                DeviceInfoItem(
                    title: "CPU 核心",
                    // activeProcessorCount 是当前可用的，processorCount 是物理总数
                    value: "\(processInfo.activeProcessorCount) / \(processInfo.processorCount)"
                ),
                DeviceInfoItem(
                    title: "物理内存",
                    value: formattedBytes(Int64(processInfo.physicalMemory), style: .memory)
                ),
            ]
        )
    }

    private static func storageGroup() -> DeviceInfoGroup {
        guard let capacity = diskCapacity() else {
            return DeviceInfoGroup(
                title: "存储",
                symbol: "internaldrive",
                items: [DeviceInfoItem(title: "磁盘容量", value: "读不到")]
            )
        }

        let used = capacity.total - capacity.free
        let ratio = Double(used) / Double(capacity.total)
        return DeviceInfoGroup(
            title: "存储",
            symbol: "internaldrive",
            items: [
                DeviceInfoItem(title: "总容量", value: formattedBytes(capacity.total, style: .file)),
                DeviceInfoItem(title: "已用", value: formattedBytes(used, style: .file)),
                DeviceInfoItem(title: "可用", value: formattedBytes(capacity.free, style: .file)),
                DeviceInfoItem(
                    title: "使用率",
                    value: ratio.formatted(.percent.precision(.fractionLength(1)))
                ),
            ]
        )
    }

    private static func batteryGroup() -> DeviceInfoGroup {
        let device = DeviceUtil()
        // iOS / watchOS 默认关闭电池监控，不打开读到的是 -1
        device.startToGetBatteryLevel()
        defer { device.stopToGetBatteryLevel() }

        let level = device.getBatteryLevel()
        return DeviceInfoGroup(
            title: "电池",
            symbol: "battery.100",
            items: [
                DeviceInfoItem(title: "电量", value: level >= 0 ? "\(level)%" : "读不到"),
                DeviceInfoItem(title: "充电中", value: device.isDeviceBatteryCharging() ? "是" : "否"),
            ]
        )
    }

    private static func screenGroup(displayScale: CGFloat) -> DeviceInfoGroup {
        DeviceInfoGroup(
            title: "屏幕",
            symbol: "display",
            items: [
                DeviceInfoItem(title: "屏幕亮度", value: brightnessText(DeviceUtil().getScreenBrightness())),
                DeviceInfoItem(title: "屏幕缩放", value: "\(Int(displayScale))x"),
                DeviceInfoItem(title: "深色模式", value: AppUtil().isDarkColorMode() ? "是" : "否"),
            ]
        )
    }

    private static func appGroup() -> DeviceInfoGroup {
        let app = AppUtil()
        return DeviceInfoGroup(
            title: "应用",
            symbol: "app",
            items: [
                DeviceInfoItem(title: "版本", value: app.getAppVersion()),
                DeviceInfoItem(title: "构建", value: app.getAppBuild()),
                DeviceInfoItem(title: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "未知"),
                DeviceInfoItem(title: "最低系统", value: app.getAppMinimumOSVersion() ?? "未知"),
            ]
        )
    }

    // MARK: - 系统 API 补位

    private static func platformName() -> String {
        let device = DeviceUtil()
        if device.isMac() { return "macOS" }
        if device.isWatch() { return "watchOS" }
        return "iOS"
    }

    /// `kern.osversion` 就是系统构建号（例如 23F77）。三个平台都可用。
    private static func systemBuildNumber() -> String {
        var size = 0
        guard sysctlbyname("kern.osversion", nil, &size, nil, 0) == 0, size > 0 else {
            return "未知"
        }

        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctlbyname("kern.osversion", &buffer, &size, nil, 0) == 0 else {
            return "未知"
        }

        // sysctl 给的是以 NUL 结尾的 C 字符串：先截掉 NUL，再按 UTF-8 解码。
        // 不走 `String(cString:)`——它对 `[CChar]` 已在新 SDK 标记 deprecated。
        let build = String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        return build.isEmpty ? "未知" : build
    }

    private static func diskCapacity() -> (total: Int64, free: Int64)? {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard
            let values = try? url.resourceValues(forKeys: [
                .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
            ]),
            let total = values.volumeTotalCapacity,
            let free = values.volumeAvailableCapacity,
            total > 0
        else { return nil }

        return (Int64(total), Int64(free))
    }

    private static func formattedBytes(
        _ bytes: Int64,
        style: ByteCountFormatter.CountStyle
    ) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: style)
    }

    private static func formattedUptime(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes / 60) % 24
        let minutes = totalMinutes % 60

        var parts: [String] = []
        if days > 0 { parts.append("\(days) 天") }
        if hours > 0 { parts.append("\(hours) 小时") }
        parts.append("\(minutes) 分钟")
        return parts.joined(separator: " ")
    }

    /// macOS 与 watchOS 没有可上架的公开亮度 API，`DeviceUtil` 约定返回 0，
    /// 只有 iOS 的返回值才是真实亮度。
    private static func brightnessText(_ brightness: Double) -> String {
        #if os(iOS)
        return "\(Int((brightness * 100).rounded()))%"
        #else
        return "不适用"
        #endif
    }

    // MARK: - 网络

    /// 标记 `nonisolated` 是必须的，不是风格问题：
    /// App target 开了 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`，如果这个函数是
    /// MainActor 隔离的，下面传给 `getNetworkType` 的闭包就会继承主线程隔离；
    /// 而 SwiftUtils 是在 Network 框架的后台队列上回调的，
    /// Swift 6 运行时的隔离检查会在那一刻直接 trap（dispatch_assert_queue_fail）。
    /// 放在 nonisolated 函数里，闭包就是 nonisolated 的，回调在哪个队列都安全。
    nonisolated private static func networkTypeLabel() async -> String {
        await withCheckedContinuation { continuation in
            NetworkUtil().getNetworkType { networkType in
                // 在回调线程上就转成 String：NetworkUtil.NetworkType 是 Swift 5 模块里的
                // public enum，没有显式 Sendable 一致性，不适合跨 continuation 传递。
                let label = networkType.map { displayName(for: $0) } ?? "无连接"
                continuation.resume(returning: label)
            } fail: { _ in
                continuation.resume(returning: "无连接")
            }
        }
    }

    /// 纯函数，标记 nonisolated 是因为它会在 NWPathMonitor 的后台队列上被调用。
    nonisolated private static func displayName(for type: NetworkUtil.NetworkType) -> String {
        switch type {
        case .is5G: return "5G"
        case .is4G: return "4G"
        case .is3G: return "3G"
        case .is2G: return "2G"
        case .wifi: return "Wi-Fi"
        case .wiredEthernet: return "以太网"
        case .other: return "其他"
        }
    }
}
