//
//  SwiftUtilsIntegrationTests.swift
//  DeviceStatusTests
//
//  这些测试验证的是「SwiftUtils 被真正链接进一个 iOS / macOS / watchOS 多平台 App 之后是否工作正常」，
//  也就是集成层面的问题：平台条件编译分支、返回值区间、以及跨平台构建时的可用性。
//
//  库自身的细粒度单元测试在 SwiftUtils 仓库（Tests/SwiftUtilsTests）里，这里不重复实现细节，
//  只钉住「在这个宿主 App 的三个平台上，公开 API 必须满足的可观测约定」。
//

import Foundation
import Testing

import SwiftUtils

@Suite("SwiftUtils 集成")
struct SwiftUtilsIntegrationTests {

    // MARK: - 平台分支

    @Test("平台判定与编译目标一致")
    func platformPredicates() {
        let device = DeviceUtil()
        #if os(macOS)
        #expect(device.isMac())
        #expect(!device.isWatch())
        #elseif os(watchOS)
        #expect(!device.isMac())
        #expect(device.isWatch())
        #else
        #expect(!device.isMac())
        #expect(!device.isWatch())
        #endif
    }

    @Test("系统版本字符串非空且带平台名")
    func systemVersionIsDescribable() {
        let version = DeviceUtil().getSystemVersion()
        #expect(!version.isEmpty)

        #if os(macOS)
        #expect(version.hasPrefix("macOS "))
        #elseif os(watchOS)
        // watchOS 分支返回 WKInterfaceDevice.systemVersion，只有版本号没有前缀
        #expect(version.first?.isNumber == true)
        #else
        #expect(version.first?.isNumber == true)
        #endif
    }

    @Test("设备名称与型号非空")
    func deviceIdentityIsReadable() {
        let device = DeviceUtil()
        #expect(!device.getDeviceName().isEmpty)
        #expect(!device.getDeviceModel().isEmpty)
    }

    // MARK: - 硬件状态

    @Test("电量落在 -1...100 区间")
    func batteryLevelIsInRange() {
        let device = DeviceUtil()
        device.startToGetBatteryLevel()
        defer { device.stopToGetBatteryLevel() }

        let level = device.getBatteryLevel()
        // -1 表示当前环境读不到（模拟器、无电池的 Mac 台式机），是文档化的失败值
        #expect(level == -1 || (0...100).contains(level))
    }

    @Test("屏幕亮度按平台返回 0...1 或 0")
    func brightnessRespectsPlatformLimits() {
        let brightness = DeviceUtil().getScreenBrightness()
        #if os(iOS)
        #expect((0.0...1.0).contains(brightness))
        #else
        // macOS 与 watchOS 没有可上架的公开亮度 API，约定返回 0
        #expect(brightness == 0)
        #endif
    }

    // MARK: - 纯函数工具（确定性断言）

    @Test("SHA 摘要是小写十六进制且值正确")
    func hashUtilitiesMatchKnownDigests() {
        let hash = HashUtil()
        #expect(hash.sha256("") == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        #expect(hash.sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(hash.sha1("abc") == "a9993e364706816aba3e25717850c26c9cd0d89d")
        #expect(hash.sha384("abc").count == 96)
        #expect(hash.sha512("abc").count == 128)
    }

    @Test("Base64 编解码可往返，非法输入原样返回")
    func base64RoundTrips() {
        let encode = EncodeUtil()
        #expect(encode.base64Encode("hello") == "aGVsbG8=")
        #expect(encode.base64Decode("aGVsbG8=") == "hello")
        #expect(encode.base64Decode(encode.base64Encode("设备状态 🍎")) == "设备状态 🍎")
        // 解不开时按实现约定回退成原字符串，而不是崩溃或空串
        #expect(encode.base64Decode("@@@not-base64@@@") == "@@@not-base64@@@")
    }

    @Test("URL 百分号编码可往返")
    func urlEncodingRoundTrips() {
        let encode = EncodeUtil()
        #expect(encode.urlEncode("a b") == "a%20b")

        for original in ["中文 参数", "a=1&b=2", "https://zzhhoo.me/路径?q=值"] {
            #expect(encode.urlDecode(encode.urlEncode(original)) == original)
        }
    }
}
