//
//  SystemClipboard.swift
//  DeviceStatus
//

import SwiftUtils

/// 对 SwiftUtils `ClipboardUtil` 的一层薄封装。
///
/// 之所以需要它：`ClipboardUtil.swift` 整个文件被 `#if !os(watchOS)` 包住，
/// 所以在 watchOS 上这个类型根本不存在。这里收口成一个不会编译失败的入口，
/// 调用方就不用到处写条件编译。
enum SystemClipboard {
    /// 当前平台是否支持写剪贴板。
    static var isSupported: Bool {
        #if os(watchOS)
        return false
        #else
        return true
        #endif
    }

    /// 写入剪贴板；返回是否真的写成功。
    @discardableResult
    static func copy(_ text: String) -> Bool {
        #if os(watchOS)
        return false
        #else
        guard !text.isEmpty else { return false }
        ClipboardUtil().setString(text)
        return true
        #endif
    }
}
