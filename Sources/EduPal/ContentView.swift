//
//  ContentView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
import SwiftData

/// 主内容视图 - 包含三个TabView: 课程表、服务、茶楼
struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(AppSettings.self) var settings
    
    @Binding var resetPasswordToken: String?
    var body: some View {
        iOSContentView(resetPasswordToken: $resetPasswordToken)
    }
}

struct iOSContentView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(AppSettings.self) var settings
    @State var teahouseSearchText = ""

    @Binding var resetPasswordToken: String?
    //@State private var showResetLoginSheet: Bool = false
    var body: some View {
        // 使用兼容的 TabView
        TabView {
            ScheduleView()
                .tabItem {
                    Label("tab.schedule".localized, systemImage: "calendar")
                }

            ServicesView()
                .tabItem {
                    Label("tab.services".localized, systemImage: "square.grid.2x2")
                }

            TeahouseView(resetPasswordToken: $resetPasswordToken)
                .tabItem {
                    Label("tab.teahouse".localized, systemImage: "cup.and.saucer")
                }
        }
    }
struct SearchTabView: View {
    @Binding var searchText: String
    @Environment(\.modelContext) var modelContext
    @Query(sort: \TeahousePost.createdAt, order: .reverse) var allPosts: [TeahousePost]
    @StateObject var authViewModel = AuthViewModel()
    @State var isSearchPresented = false

    private var backgroundColor: Color {
        Color(.systemBackground)
    }

    private var searchResults: [TeahousePost] {
        guard !searchText.isEmpty else { return [] }
        return allPosts.filter { post in
            post.title.localizedCaseInsensitiveContains(searchText) ||
            post.content.localizedCaseInsensitiveContains(searchText) ||
            post.author.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text(NSLocalizedString("teahouse.search_title", comment: "Search"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

                if searchText.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text(NSLocalizedString("teahouse.search_hint", comment: "Enter keywords to search"))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(backgroundColor)
                } else if searchResults.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text(NSLocalizedString("teahouse.no_results", comment: "No posts found"))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(backgroundColor)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(searchResults) { post in
                                NavigationLink {
                                    PostDetailView(post: post)
                                        .environmentObject(authViewModel)
                                } label: {
                                    PostRow(post: post, onLike: { }, authViewModel: authViewModel)
                                        .padding(.horizontal, 16)
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .background(backgroundColor)
                }
            }
            .searchable(text: $searchText, isPresented: $isSearchPresented)
            .onAppear {
                // 返回时收起搜索栏与键盘
                isSearchPresented = false
            }
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State var token: String? = nil
        var body: some View {
            ContentView(resetPasswordToken: $token)
                .environment(AppSettings())
                .modelContainer(for: [Course.self, Schedule.self], inMemory: true)
        }
    }
    static var previews: some View {
        PreviewWrapper()
    }
}
#endif