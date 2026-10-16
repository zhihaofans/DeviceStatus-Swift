//
//  DeviceInfo.swift
//  DeviceStatus
//

import Foundation

/// 一条设备信息。
///
/// `id` 用 `title` 派生而不是 `UUID`：刷新时身份保持稳定，
/// 列表不会因为重新采集数据而整体重建、丢失选中态或触发多余动画。
struct DeviceInfoItem: Identifiable, Hashable {
    let title: String
    let value: String

    var id: String { title }

    /// 复制到剪贴板时使用的文本。
    var copyText: String { "\(title): \(value)" }
}

/// 一组相关的设备信息。
struct DeviceInfoGroup: Identifiable, Hashable {
    let title: String
    let symbol: String
    let items: [DeviceInfoItem]

    var id: String { title }

    init(title: String, symbol: String, items: [DeviceInfoItem]) {
        self.title = title
        self.symbol = symbol
        self.items = items
    }

    /// 只保留匹配关键字的条目；没有命中则返回 nil（供搜索过滤使用）。
    func filtered(matching keyword: String) -> DeviceInfoGroup? {
        guard !keyword.isEmpty else { return self }

        let matched = items.filter {
            $0.title.localizedCaseInsensitiveContains(keyword)
                || $0.value.localizedCaseInsensitiveContains(keyword)
        }
        guard !matched.isEmpty else { return nil }

        return DeviceInfoGroup(title: title, symbol: symbol, items: matched)
    }
}
