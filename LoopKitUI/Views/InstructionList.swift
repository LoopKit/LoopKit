//
//  InstructionList.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-02-20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct InstructionList: View {
    struct Instruction {
        let text: String
        let subtext: String?
    }
    let instructions: [Instruction]
    let startingIndex: Int
    let instructionColor: Color
    
    // Setting this to true will also disable swiftui's localization,
    // so the instruction should in those cases be pre-localized in those cases
    public var markdownEnabled: Bool
    
    @Environment(\.isEnabled) var isEnabled
    
    public init(instructions: [String], startingIndex: Int = 1, instructionColor: Color = .primary, markdownEnabled : Bool = false) {
        self.instructions = instructions.map { Instruction(text: $0, subtext: nil) }
        self.startingIndex = startingIndex
        self.instructionColor = instructionColor
        self.markdownEnabled = markdownEnabled
    }
    
    public init(instructions: [(String, String)], startingIndex: Int = 1, instructionColor: Color = .primary, markdownEnabled : Bool = false) {
        self.instructions = instructions.map { Instruction(text: $0.0, subtext: $0.1) }
        self.startingIndex = startingIndex
        self.instructionColor = instructionColor
        self.markdownEnabled = markdownEnabled
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(instructions.indices, id: \.self) { index in
                HStack(alignment: .top) {
                    Text("\(index+startingIndex)")
                        .opacity(isEnabled ? 1.0 : 0.8)
                        .padding(6)
                        .background(Circle().fill(Color.accentColor))
                        .foregroundColor(Color.white)
                        .font(.caption)
                        .accessibility(label: Text("\(index+1), ")) // Adds a pause after the number
                    instructionView(instructions[index], markdownEnabled: markdownEnabled)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
    
    @ViewBuilder
    private func instructionView(_ instruction: Instruction, markdownEnabled: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            
            if markdownEnabled {
                Text(LocalizedStringKey(instruction.text))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(instruction.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if let subtext = instruction.subtext {
                if markdownEnabled {
                    Text(LocalizedStringKey(subtext))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(isEnabled ? instructionColor : Color.secondary)
                        .font(.caption)
                } else {
                    Text(subtext)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(isEnabled ? instructionColor : Color.secondary)
                        .font(.caption)
                }
            }
        }
        .padding(2)
        .foregroundColor(isEnabled ? instructionColor : Color.secondary)
    }
}

struct InstructionList_Previews: PreviewProvider {
    static var previews: some View {
        let instructions: [String] = [
            "This is the first step.",
            "This second step is a bit more tricky and needs **more** description to support the user or maybe a [link](https://google.com) with more info",
            "With this final step, the task will be accomplished."
        ]
        return InstructionList(instructions: instructions, markdownEnabled: true)
    }
}
