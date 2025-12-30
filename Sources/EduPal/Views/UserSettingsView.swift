//
//  UserSettingsView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/03.
//

import SwiftUI
import UserNotifications
import SwiftData

/// 用户设置视图
struct UserSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(AppSettings.self) var settings
    
    @Query var schedules: [Schedule]
    
    @Binding var showManageSchedules: Bool
    @Binding var showLoginSheet: Bool
    @Binding var showImagePicker: Bool
    
    @State var showSemesterDatePicker = false
    @State var showLogoutConfirmation = false
    @State var showNotificationSettings = false
    @State var showCalendarPermissionError = false
    @State var calendarPermissionError: String?
    
    private var defaultUserImage: some View {
            .font(.system(size: 60))
            .foregroundStyle(.blue)
        #else
        Image(systemName: "person.crop.circle.badge.checkmark")
            .font(.system(size: 50))
            .foregroundStyle(.blue)
    }
    
    var body: some View {
        Group {
            NavigationStack {
                List {
                    userInfoSection
                    scheduleManagementSection
                    semesterSettingsSection
                    displaySettingsSection
                    appearanceSettingsSection
                    otherFunctionsSection
                    accountActionsSection
                }
                .navigationTitle("settings.title".localized)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("done".localized) {
                            dismiss()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSemesterDatePicker) {
            NavigationStack {
                VStack(spacing: 0) {
                    DatePicker(
                        selection: Binding(
                            get: { settings.semesterStartDate },
                            set: { settings.semesterStartDate = $0 }
                        ),
                        displayedComponents: [.date]
                    ) {
                        Text("settings.select_semester_start".localized)
                    }
                    .datePickerStyle(.graphical)
                    .padding()
                    .frame(maxHeight: .infinity)
                    
                    Spacer(minLength: 0)
                }
                .navigationTitle("settings.semester_start".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("confirm".localized) {
                            showSemesterDatePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.large])
        }
        .alert("calendar.permission_error".localized, isPresented: $showCalendarPermissionError) {
            Button("ok".localized, role: .cancel) { }
        } message: {
            Text(calendarPermissionError ?? "calendar.permission_denied".localized)
        }
        .onChange(of: settings.enableCalendarSync) { _, newValue in
            Task {
                if newValue {
                    // 启用日历同步
                    do {
                        try await CalendarSyncManager.requestAccess()
                        // 权限获取成功，同步当前课表
                        if let activeSchedule = schedules.first(where: { $0.isActive }) {
                            let scheduleId = activeSchedule.id
                            let descriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.scheduleId == scheduleId })
                            if let courses = try? modelContext.fetch(descriptor) {
                                try await CalendarSyncManager.sync(schedule: activeSchedule, courses: courses, settings: settings)
                            }
                        }
                    } catch {
                        await MainActor.run {
                            settings.enableCalendarSync = false
                            calendarPermissionError = error.localizedDescription
                            showCalendarPermissionError = true
                        }
                    }
                } else {
                    // 关闭日历同步，删除日历中添加的所有日程
                    try await CalendarSyncManager.clearAllEvents()
                }
            }
        }
    
    // MARK: - Section 视图
    
    private var userInfoSection: some View {
        Section {
            if settings.isLoggedIn {
                NavigationLink(destination: UserInfoView().environment(settings)) {
                    userInfoContent
                }
            } else {
                Button(action: {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showLoginSheet = true
                    }
                }) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.system(size: 50))
                            .foregroundStyle(.gray)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("settings.not_logged_in".localized)
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("settings.login_hint".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 8)
                        .foregroundStyle(.primary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    private var userInfoContent: some View {
        HStack(spacing: 16) {
            // 显示用户头像或默认图标
            let avatarSize: CGFloat = 50
            
            if let avatarPath = settings.userAvatarPath {
                #if canImport(UIKit)
                if let uiImage = UIImage(contentsOfFile: avatarPath) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 2.5)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                } else {
                    defaultUserImage
                }
                #else
                if let nsImage = NSImage(contentsOfFile: avatarPath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 2.5)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                } else {
                    defaultUserImage
                }
            } else {
                defaultUserImage
            }
            
            VStack(alignment: .leading, spacing: 6) {
                if let displayName = settings.userDisplayName ?? settings.username {
                    Text(displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("settings.logged_in".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 12)
    }
    
    private var scheduleManagementSection: some View {
        Section {
            NavigationLink(destination: ManageSchedulesView().environment(settings)) {
                Label("settings.manage_schedules".localized, systemImage: "list.bullet")
            }
            Toggle(
                isOn: Binding(
                    get: { settings.enableCalendarSync },
                    set: { settings.enableCalendarSync = $0 }
                )
            ) {
                Label("calendar.sync_to_system".localized, systemImage: "calendar")
            }
        } header: {
            Text("settings.schedule_management".localized)
        }
    }
    
    private var semesterSettingsSection: some View {
        Section {
            Button(action: { showSemesterDatePicker = true }) {
                HStack {
                    Label("settings.semester_start".localized, systemImage: "calendar.badge.clock")
                        .foregroundStyle(.blue)
                    Spacer()
                    Text(dateFormatter.string(from: settings.semesterStartDate))
                        .foregroundStyle(.secondary)
                        .font(.body)
                }
            }
            .foregroundStyle(.primary)
            
            Picker(selection: Binding(
                get: { settings.weekStartDay },
                set: { settings.weekStartDay = $0 }
            )) {
                ForEach(AppSettings.WeekStartDay.allCases, id: \.rawValue) { day in
                    Text(day.displayName).tag(day)
                }
            } label: {
                Label("settings.week_start_day".localized, systemImage: "calendar")
            }
        } header: {
            Text("settings.semester_settings".localized)
        } footer: {
            Text("settings.semester_hint".localized)
        }
    
    private var displaySettingsSection: some View {
        Section("settings.display_settings".localized) {
            Picker("settings.calendar_start_time".localized, selection: Binding(
                get: { settings.calendarStartHour },
                set: { settings.calendarStartHour = $0 }
            )) {
                ForEach(6...12, id: \.self) { hour in
                    Text("\(hour):00").tag(hour)
                }
            }
            
            Picker("settings.calendar_end_time".localized, selection: Binding(
                get: { settings.calendarEndHour },
                set: { settings.calendarEndHour = $0 }
            )) {
                ForEach(18...23, id: \.self) { hour in
                    Text("\(hour):00").tag(hour)
                }
            }
            
            Toggle(isOn: Binding(
                get: { settings.showGridLines },
                set: { settings.showGridLines = $0 }
            )) {
                Label("settings.show_grid_lines".localized, systemImage: "squareshape.split.3x3")
            }
            
            Toggle(isOn: Binding(
                get: { settings.showTimeRuler },
                set: { settings.showTimeRuler = $0 }
            )) {
                Label("settings.show_time_ruler".localized, systemImage: "ruler")
            }

            // 新增：显示当前时间线开关
            Toggle(isOn: Binding(
                get: { settings.showCurrentTimeline },
                set: { settings.showCurrentTimeline = $0 }
            )) {
                Label("settings.show_current_timeline".localized, systemImage: "calendar.day.timeline.left")
                VStack(alignment: .leading) {
                    if settings.timelineDisplayMode == .classTime {
                        Text("settings.show_current_timeline_desc_disabled".localized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(settings.timelineDisplayMode == .classTime) // 当时间轴显示方式为课程时间显示时禁用
            
            Picker(selection: Binding(
                get: { settings.timelineDisplayMode },
                set: { settings.timelineDisplayMode = $0 }
            )) {
                ForEach(AppSettings.TimelineDisplayMode.allCases, id: \.rawValue) { mode in
                    Text(mode.displayName).tag(mode)
                }
            } label: {
                Label("settings.timeline_display_mode".localized, systemImage: "timeline.selection")
            }
        }
    }
    
    private var appearanceSettingsSection: some View {
        Section("settings.appearance_settings".localized) {
            #if canImport(SwiftUI)
            if #available(iOS 26, macOS 26, *) {
                Toggle(isOn: Binding(
                    get: { settings.useLiquidGlass },
                    set: { settings.useLiquidGlass = $0 }
                )) {
                    Text("settings.use_liquid_glass".localized)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Label("settings.course_block_opacity".localized, systemImage: "square.fill")
                if settings.useLiquidGlass {
                    Text("settings.course_block_opacity_disabled_with_glass".localized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 0) {
                    Text("50%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .leading)
                    
                    GeometryReader { geometry in
                        VStack(spacing: 6) {
                            Slider(value: Binding(
                                get: { settings.courseBlockOpacity },
                                set: { newValue in
                                    let oldValue = settings.courseBlockOpacity
                                    let rounded = round(newValue * 10) / 10
                                    settings.courseBlockOpacity = rounded
                                    
                                    #if os(iOS)
                                    let oldStep = round(oldValue * 10)
                                    let newStep = round(rounded * 10)
                                    if oldStep != newStep {
                                        let impact = UIImpactFeedbackGenerator(style: .light)
                                        impact.impactOccurred()
                                    }
                                }
                            ), in: 0.5...1.0, step: 0.1)
                            .padding(10)
                            .disabled(settings.useLiquidGlass)
                            
                            #if !os(visionOS)
                            HStack(spacing: 0) {
                                ForEach(0..<6, id: \.self) { index in
                                    let value = 0.5 + Double(index) * 0.1
                                    let isActive = abs(settings.courseBlockOpacity - value) < 0.05
                                    
                                    ZStack {
                                        Circle()
                                            .fill(isActive ? Color.blue : Color.gray.opacity(0.3))
                                            .frame(width: isActive ? 8 : 6, height: isActive ? 8 : 6)
                                            .animation(.spring(response: 0.3), value: isActive)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.horizontal, 2)
                            .disabled(settings.useLiquidGlass)
                        }
                        .frame(width: geometry.size.width)
                    }
                    .frame(height: 44)
                    
                    Text("100%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                
                Text("\(Int(settings.courseBlockOpacity * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            
            Toggle(isOn: Binding(
                get: { settings.backgroundImageEnabled && settings.backgroundImagePath != nil },
                set: { isOn in
                    if isOn {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showImagePicker = true
                        }
                    } else {
                        settings.backgroundImagePath = nil
                        settings.backgroundImageEnabled = false
                    }
                }
            )) {
                Label("settings.background_image".localized, systemImage: "photo")
            }
            
            // 新增：背景透明度滑块，仅在背景图片启用时显示
            if settings.backgroundImageEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Label("settings.background_opacity".localized, systemImage: "slider.horizontal.below.circle.righthalf.filled.inverse")
                    
                    HStack(spacing: 0) {
                        Text("0%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .leading)
                        
                        GeometryReader { geometry in
                            VStack(spacing: 6) {
                                Slider(value: Binding(
                                    get: { settings.backgroundOpacity },
                                    set: { newValue in
                                        let oldValue = settings.backgroundOpacity
                                        let rounded = round(newValue * 100) / 100 // 精确到百分位
                                        settings.backgroundOpacity = rounded
                                        
                                        #if os(iOS)
                                        let oldStep = round(oldValue * 10)
                                        let newStep = round(rounded * 10)
                                        if oldStep != newStep {
                                            let impact = UIImpactFeedbackGenerator(style: .light)
                                            impact.impactOccurred()
                                        }
                                    }
                                ), in: 0.0...1.0, step: 0.01) // 步长改为0.01
                                .padding(10)
                                
                                #if !os(visionOS)
                                // 可选的视觉反馈，类似课程块透明度
                                HStack(spacing: 0) {
                                    ForEach(0..<11, id: \.self) { index in // 0%到100%
                                        let value = Double(index) * 0.1
                                        let isActive = abs(settings.backgroundOpacity - value) < 0.05
                                        
                                        ZStack {
                                            Circle()
                                                .fill(isActive ? Color.blue : Color.gray.opacity(0.3))
                                                .frame(width: isActive ? 8 : 6, height: isActive ? 8 : 6)
                                                .animation(.spring(response: 0.3), value: isActive)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                            .frame(width: geometry.size.width)
                        }
                        .frame(height: 44)
                        
                        Text("100%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                    
                    Text("\(Int(settings.backgroundOpacity * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var otherFunctionsSection: some View {
        Section {
            NavigationLink(destination: NotificationSettingsView().environment(settings)) {
                Label("settings.notifications".localized, systemImage: "bell")
            }
        } header: {
            Text("settings.other".localized)
        }
    }
    
    private var accountActionsSection: some View {
        Section {
            if settings.isLoggedIn {
                Button(role: .destructive, action: {
                    showLogoutConfirmation = true
                }) {
                    HStack {
                        Spacer()
                        Text("settings.logout".localized)
                        Spacer()
                    }
                }
                .alert("settings.logout_confirm_title".localized, isPresented: $showLogoutConfirmation) {
                    Button("cancel".localized, role: .cancel) { }
                    Button("settings.logout".localized, role: .destructive) {
                        settings.logout()
                        dismiss()
                    }
                } message: {
                    Text("settings.logout_confirm_message".localized)
                }
            }
        }
    }
    
    // MARK: - macOS Support
    


#endif
#endif
#endif
#endif
#endif
#endif
#endif
#endif