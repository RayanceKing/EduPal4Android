//
//  ImageCropView.swift
//  EduPal
//
//  Created by rayanceking on 2025/12/5.
//

import SwiftUI

/// 图片裁剪视图（Android版本简化实现）
struct ImageCropView: View {
    let image: Any
    let onCrop: (Any?) -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            Text("图片裁剪功能暂不可用")
                .font(.title)
                .padding()

            Button("关闭") {
                dismiss()
            }
            .padding()
        }
        .frame(width: 400, height: 300)
    }

/// Helper to avoid deprecated onChange signature on visionOS.
struct ViewportChangeModifier: ViewModifier {
    let size: CGSize
    let onChange: (CGSize) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17, visionOS 1, *) {
            content.onChange(of: size) { _, newValue in
                onChange(newValue)
            }
        } else {
            content.onChange(of: size) { newValue in
                onChange(newValue)
            }
        }
