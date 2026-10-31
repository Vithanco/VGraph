public enum IconPosition: Int, VProtocol {
    case none = 0
    case left = 1
    case center = 2
    case top = 3

    static var readableNames: [String] {
        return ["No Icon", "Left", "Center", "Top"]
    }
}

public struct IconInfo: CustomStringConvertible, VProtocol {
    public var iconPosition: IconPosition
    public var iconName: String
    public var iconColor: VColor
    public var iconSize: Double

    func padding(_ by: Double) -> IconInfo {
        return IconInfo(
            iconPosition: self.iconPosition, iconName: self.iconName, iconColor: self.iconColor,
            iconSize: self.iconSize - by * 2)
    }
    public init(iconPosition: IconPosition, iconName: String, iconColor: VColor, iconSize: Double) {
        self.iconPosition = iconPosition
        self.iconName = iconName
        self.iconColor = iconColor
        self.iconSize = iconSize
    }

    public var description: String {
        return
            "IconInfo(iconPosition: \(iconPosition), iconName: \(iconName), iconColor: \(iconColor), iconSize: \(iconSize))"
    }

}

extension IconInfo: AttributeType {
    public static var typeName: String {
        return "IconInfo"
    }

    public static func fromString(_ string: String) throws(VError) -> IconInfo {
        let parts = string.split(separator: "|", maxSplits: 3).map(String.init)
        guard parts.count == 4 else {
            throw VError.conversionError(from: string, to: typeName)
        }

        guard let positionRaw = Int(parts[0]),
            let position = IconPosition(rawValue: positionRaw)
        else {
            throw VError.conversionError(from: string, to: typeName)
        }

        let iconName = parts[1]
        let iconColor = try VColor.fromString(parts[2])

        guard let iconSize = Double(parts[3]) else {
            throw VError.conversionError(from: string, to: typeName)
        }

        return IconInfo(iconPosition: position, iconName: iconName, iconColor: iconColor, iconSize: iconSize)
    }

    public var asString: String {
        return "\(iconPosition.rawValue)|\(iconName)|\(iconColor.asString)|\(iconSize)"
    }
}
