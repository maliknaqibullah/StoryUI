//
//  ProgressView.swift
//  StoryUI (iOS)
//
//  Created by Tolga İskender on 29.04.2022.
//

import SwiftUI

struct ProgressBarView: View {
    let progress: CGFloat
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background bar
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)
                
                // Foreground progress
                if isActive {
                    Capsule()
                        .fill(Color.white)
                        .frame(width: geometry.size.width * progress, height: 4)
                } else if isCompleted {
                    Capsule()
                        .fill(Color.white)
                        .frame(width: geometry.size.width, height: 4)
                }
            }
        }
        .frame(height: 4)
    }
}
