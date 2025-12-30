//
//  CalendarSyncManager.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/05.
//

import Foundation

struct CalendarSyncManager {
    /// 日历同步管理器 - Android版本简化实现
    static func requestCalendarAccess() async -> Bool {
        // Android版本暂不支持日历同步
        return false
    }

    static func openAppSettings() {
        // Android版本暂不支持打开应用设置
        print("Opening app settings is not supported on Android.")
    }

    static func sync(schedule: Schedule, courses: [Course], settings: AppSettings) async throws {
        // Android版本暂不支持日历同步
        print("Calendar sync is not supported on Android.")
    }

    static func clearAllEvents() async throws {
        // Android版本暂不支持日历同步
        print("Calendar sync is not supported on Android.")
    }

    static func disableSyncAndClear() async {
        // Android版本暂不支持日历同步
        print("Calendar sync is not supported on Android.")
    }
}

#if canImport(EventKit) && canImport(UIKit)
import EventKit

extension CalendarSyncManager {
    private static let eventStore = EKEventStore()
    private static let calendarIdentifierKey = "EduPalCalendarIdentifier"

    /// 获取可用的日历列表
    static func availableCalendars() -> [EKCalendar] {
        var result: [EKCalendar] = []
        let calendars = eventStore.calendars(for: .event)
        // 1) 先根据已保存的 identifier 精确匹配
        if let savedID = UserDefaults.standard.string(forKey: calendarIdentifierKey),
           let savedCalendar = eventStore.calendar(withIdentifier: savedID) {
            result.append(savedCalendar)
        }
        // 2) 再补充所有标题为 EduPal 的日历（去重）
        let titled = calendars.filter { $0.title == "EduPal" }
        for cal in titled where !result.contains(where: { $0.calendarIdentifier == cal.calendarIdentifier }) {
            result.append(cal)
        }
        return result

    enum SyncError: Error {
        case accessDenied
        case accessRestricted
        case calendarNotFound
    }

    /// 请求日历权限（始终索要完整访问权限）
    static func requestAccess() async throws {
        try await requestFullAccess()
    }

    /// 请求日历权限（完整访问以支持读写操作）
    static func requestFullAccess() async throws {
        if #available(iOS 17.0, macOS 14.0, *) {
            let status = EKEventStore.authorizationStatus(for: .event)
            if status == .fullAccess { return }
            if status == .denied { throw SyncError.accessDenied }
            if status == .restricted { throw SyncError.accessRestricted }
            let granted = try await eventStore.requestFullAccessToEvents()
            if !granted { throw SyncError.accessDenied }
        } else {
            let status = EKEventStore.authorizationStatus(for: .event)
            if status == .authorized { return }
            if status == .denied { throw SyncError.accessDenied }
            if status == .restricted { throw SyncError.accessRestricted }
            let granted = try await eventStore.requestAccess(to: .event)
            if !granted { throw SyncError.accessDenied }
        }
    }

    /// 同步课程表到日历
    static func sync(schedule: Schedule, courses: [Course], settings: AppSettings) async throws {
        // 检查权限
        try await requestAccess()

        // 获取目标日历
        guard let calendar = getOrCreateCalendar() else {
            throw SyncError.calendarNotFound
        }

        // 清除现有事件
        try await clearAllEvents()

        // 创建新事件
        for course in courses {
            try await createEvent(for: course, in: calendar, settings: settings)
        }
    }

    /// 获取或创建 EduPal 日历
    private static func getOrCreateCalendar() -> EKCalendar? {
        // 先尝试获取已存在的日历
        if let existing = availableCalendars().first {
            return existing
        }

        // 创建新日历
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = "EduPal"
        calendar.cgColor = UIColor.systemBlue.cgColor

        // 添加到默认来源
        guard let source = eventStore.sources.first(where: { $0.sourceType == .local }) ?? eventStore.sources.first else {
            return nil
        }
        calendar.source = source

        do {
            try eventStore.saveCalendar(calendar, commit: true)
            // 保存日历标识符
            UserDefaults.standard.set(calendar.calendarIdentifier, forKey: calendarIdentifierKey)
            return calendar
        } catch {
            print("Failed to create calendar: \(error)")
            return nil
        }

    /// 为课程创建日历事件
    private static func createEvent(for course: Course, in calendar: EKCalendar, settings: AppSettings) async throws {
        // 为每一周的课程创建事件
        for week in course.weeks {
            let event = EKEvent(eventStore: eventStore)
            event.title = course.name
            event.location = course.location
            event.calendar = calendar
            event.notes = "教师: \(course.teacher)\n周次: 第\(week)周"

            // 设置时间
            let classTime = ClassTimeManager.shared.getClassTime(for: course.timeSlot)
            guard let startTime = classTime?.startTime, let endTime = classTime?.endTime else { continue }

            // 解析时间字符串
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm"

            guard let startDateTime = dateFormatter.date(from: startTime),
                  let endDateTime = dateFormatter.date(from: endTime),
                  let weekStart = schedule.weekStartDate(for: week) else { continue }

            // 计算这周的课程日期
            let courseDate = Calendar.current.date(byAdding: .day, value: course.dayOfWeek - 1, to: weekStart)
            guard let courseDate = courseDate else { continue }

            // 合并日期和时间
            let startComponents = Calendar.current.dateComponents([.year, .month, .day], from: courseDate)
            let startHour = Calendar.current.component(.hour, from: startDateTime)
            let startMinute = Calendar.current.component(.minute, from: startDateTime)
            let endHour = Calendar.current.component(.hour, from: endDateTime)
            let endMinute = Calendar.current.component(.minute, from: endDateTime)

            var eventStartComponents = DateComponents()
            eventStartComponents.year = startComponents.year
            eventStartComponents.month = startComponents.month
            eventStartComponents.day = startComponents.day
            eventStartComponents.hour = startHour
            eventStartComponents.minute = startMinute

            var eventEndComponents = DateComponents()
            eventEndComponents.year = startComponents.year
            eventEndComponents.month = startComponents.month
            eventEndComponents.day = startComponents.day
            eventEndComponents.hour = endHour
            eventEndComponents.minute = endMinute

            guard let eventStart = Calendar.current.date(from: eventStartComponents),
                  let eventEnd = Calendar.current.date(from: eventEndComponents) else { continue }

            let courseEvent = EKEvent(eventStore: eventStore)
            courseEvent.title = course.name
            courseEvent.location = course.location
            courseEvent.startDate = eventStart
            courseEvent.endDate = eventEnd
            courseEvent.calendar = calendar
            courseEvent.notes = "教师: \(course.teacher)\n周次: 第\(week)周"

            // 设置提醒
            if settings.calendarReminderEnabled {
                let alarm = EKAlarm(relativeOffset: -TimeInterval(settings.calendarReminderMinutes * 60))
                courseEvent.addAlarm(alarm)
            }

            try eventStore.save(courseEvent, span: .thisEvent)
        }
    }

    /// 清除所有 EduPal 相关事件
    static func clearAllEvents() async throws {
        let calendars = availableCalendars()
        let predicate = eventStore.predicateForEvents(withStart: Date.distantPast, end: Date.distantFuture, calendars: calendars)

        let events = eventStore.events(matching: predicate)
        for event in events where event.title.contains("EduPal") || event.calendar.title == "EduPal" {
            try eventStore.remove(event, span: .thisEvent)
        }
    }

    /// 禁用同步并清除所有事件
    static func disableSyncAndClear() async {
        do {
            try await clearAllEvents()
            // 清除保存的日历标识符
            UserDefaults.standard.removeObject(forKey: calendarIdentifierKey)
        } catch {
            print("Failed to clear events: \(error)")
        }
    }

    /// 打开应用设置页面
    static func openAppSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            Task {
                await MainActor.run {
                    UIApplication.shared.open(url)
                }
            }
        }
        #elseif canImport(AppKit)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            // macOS 可以尝试直接打开到隐私-日历设置，但路径可能因macOS版本而异
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            // 回退到隐私设置面板
            NSWorkspace.shared.open(url)
        } else {
            // 最终回退到应用设置
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
        #else
        // 其他平台（如 watchOS, tvOS）可能没有直接打开应用设置的API
        print("Opening app settings is not directly supported on this platform.")
        #endif
    }
}
#endif
#endif