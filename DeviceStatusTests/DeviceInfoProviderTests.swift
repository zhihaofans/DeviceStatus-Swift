//
//  DeviceInfoProviderTests.swift
//  DeviceStatusTests
//
//  针对采集层本身的测试。这里不重复 SwiftUtils 的单元测试，
//  而是钉住「采集出来的数据一定是可展示的」这件事。
//

import Foundation
import Testing

@testable import DeviceStatus

@MainActor
@Suite("设备信息采集")
struct DeviceInfoProviderTests {

    @Test("分组齐全、每个条目都有标题和值")
    func snapshotIsWellFormed() {
        let groups = DeviceInfoProvider.snapshot(displayScale: 2)

        #expect(!groups.isEmpty)
        for group in groups {
            #expect(!group.title.isEmpty)
            #expect(!group.symbol.isEmpty)
            #expect(!group.items.isEmpty, "分组「\(group.title)」没有条目")

            for item in group.items {
                #expect(!item.title.isEmpty)
                #expect(!item.value.isEmpty, "条目「\(item.title)」的值为空")
            }
        }
    }

    @Test("包含预期的分组")
    func snapshotHasExpectedGroups() {
        let titles = DeviceInfoProvider.snapshot(displayScale: 2).map(\.title)
        for expected in ["系统", "硬件", "存储", "电池", "屏幕", "应用"] {
            #expect(titles.contains(expected), "缺少分组「\(expected)」")
        }
    }

    @Test("分组内条目标题唯一：id 由标题派生，重复会让列表身份错乱")
    func itemTitlesAreUniqueWithinEachGroup() {
        for group in DeviceInfoProvider.snapshot(displayScale: 2) {
            let titles = group.items.map(\.title)
            #expect(Set(titles).count == titles.count, "分组「\(group.title)」有重复标题")
        }
    }

    @Test("屏幕缩放来自入参，原样反映到条目上")
    func displayScaleIsReflected() {
        let groups = DeviceInfoProvider.snapshot(displayScale: 3)
        let group = try? #require(groups.first { $0.title == "屏幕" })
        let item = group?.items.first { $0.title == "屏幕缩放" }
        #expect(item?.value == "3x")
    }

    @Test("网络分组异步返回连接类型")
    func networkGroupLoads() async {
        let group = await DeviceInfoProvider.loadNetworkGroup()

        #expect(group.title == "网络")
        #expect(group.items.count == 1)
        #expect(group.items.first?.title == "连接类型")
        #expect(group.items.first?.value.isEmpty == false)
    }

    @Test("复制文本是「标题: 值」")
    func copyTextIsTitleColonValue() {
        let item = DeviceInfoItem(title: "电量", value: "88%")
        #expect(item.copyText == "电量: 88%")
    }

    @Test("plainText 带分组标题与缩进条目")
    func plainTextIsFormatted() {
        let groups = [
            DeviceInfoGroup(
                title: "系统",
                symbol: "gearshape",
                items: [DeviceInfoItem(title: "版本", value: "26.0")]
            )
        ]

        let text = DeviceInfoProvider.plainText(groups)
        #expect(text.contains("系统"))
        #expect(text.contains("  版本: 26.0"))
    }

    @Test("搜索过滤：命中保留、未命中整组隐藏、大小写不敏感")
    func filteringKeepsOnlyMatches() {
        let group = DeviceInfoGroup(
            title: "系统",
            symbol: "gearshape",
            items: [
                DeviceInfoItem(title: "版本", value: "26.0"),
                DeviceInfoItem(title: "时区", value: "Asia/Shanghai"),
            ]
        )

        #expect(group.filtered(matching: "版本")?.items.count == 1)
        #expect(group.filtered(matching: "shanghai")?.items.count == 1)
        #expect(group.filtered(matching: "不存在") == nil)
        #expect(group.filtered(matching: "")?.items.count == 2)
    }
}
