//
//  ContentView.swift
//  DeviceStatus
//
//  Created by zzh on 2026/10/15.
//

import SwiftUI
import SwiftUtils

struct ContentView: View {
    /// 屏幕缩放和配色方案都要问 SwiftUI 环境，所以从视图传进采集层。
    @Environment(\.displayScale) private var displayScale
    @Environment(\.colorScheme) private var colorScheme

    @State private var groups: [DeviceInfoGroup] = []
    @State private var networkGroup: DeviceInfoGroup?
    @State private var searchText = ""
    @State private var copiedItemID: String?
    @State private var didCopyAll = false
    @State private var hasLoaded = false

    /// 网络分组插在「硬件」之后，和其它分组一起参与搜索。
    private var allGroups: [DeviceInfoGroup] {
        guard let networkGroup else { return groups }
        var merged = groups
        merged.insert(networkGroup, at: min(2, merged.count))
        return merged
    }

    private var visibleGroups: [DeviceInfoGroup] {
        allGroups.compactMap { $0.filtered(matching: searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleGroups) { group in
                    Section {
                        ForEach(group.items) { item in
                            infoRow(item)
                        }
                    } header: {
                        Label(group.title, systemImage: group.symbol)
                    }
                }
            }
            .navigationTitle("设备状态")
            .searchable(text: $searchText, prompt: "搜索信息项")
            .refreshable { await reload() }
            .toolbar {
                if SystemClipboard.isSupported {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            copyAll()
                        } label: {
                            Label(
                                didCopyAll ? "已复制" : "复制全部",
                                systemImage: didCopyAll ? "checkmark.circle.fill" : "doc.on.doc"
                            )
                        }
                    }
                }
            }
            .overlay {
                if !hasLoaded {
                    ProgressView()
                }
            }
            .task { await reload() }
            // 切换白天/深夜后「深色模式」这一行会变旧，顺便把整份信息重采一次。
            // 只重采本地就能拿到的那部分：网络类型跟外观无关，不必再走一次 NWPathMonitor。
            .onChange(of: colorScheme) {
                refreshLocalGroups()
            }
        }
    }

    // MARK: - 行

    private func infoRow(_ item: DeviceInfoItem) -> some View {
        HStack(spacing: 8) {
            Text(item.title)
            Spacer(minLength: 8)
            Text(item.value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
            if copiedItemID == item.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // watchOS 上没有剪贴板，点击不做任何事
            guard SystemClipboard.isSupported else { return }
            copy(item)
        }
        .contextMenu {
            if SystemClipboard.isSupported {
                Button("复制") { copy(item) }
            }
        }
    }

    // MARK: - 动作

    /// 重采本地就能拿到的分组（系统 / 硬件 / 存储 / 电池 / 屏幕 / 应用）。
    private func refreshLocalGroups() {
        groups = DeviceInfoProvider.snapshot(displayScale: displayScale)
    }

    private func reload() async {
        refreshLocalGroups()
        networkGroup = await DeviceInfoProvider.loadNetworkGroup()
        hasLoaded = true
    }

    private func copy(_ item: DeviceInfoItem) {
        guard SystemClipboard.copy(item.copyText) else { return }

        copiedItemID = item.id
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            if copiedItemID == item.id { copiedItemID = nil }
        }
    }

    /// 复制当前**可见**的内容——搜索过滤后就只复制命中的条目。
    private func copyAll() {
        guard SystemClipboard.copy(DeviceInfoProvider.plainText(visibleGroups)) else { return }

        didCopyAll = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            didCopyAll = false
        }
    }
}

#Preview {
    ContentView()
}
