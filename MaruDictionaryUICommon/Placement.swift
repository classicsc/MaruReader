//
//  Placement.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/23/25.
//

public enum Placement {
    case belowLeftAligned
    case belowRightAligned
    case aboveLeftAligned
    case aboveRightAligned
    case rightTopAligned
    case rightBottomAligned
    case leftTopAligned
    case leftBottomAligned

    var description: String {
        switch self {
        case .belowLeftAligned:
            "Below Left Aligned"
        case .belowRightAligned:
            "Below Right Aligned"
        case .aboveLeftAligned:
            "Above Left Aligned"
        case .aboveRightAligned:
            "Above Right Aligned"
        case .rightTopAligned:
            "Right Top Aligned"
        case .rightBottomAligned:
            "Right Bottom Aligned"
        case .leftTopAligned:
            "Left Top Aligned"
        case .leftBottomAligned:
            "Left Bottom Aligned"
        }
    }
}
