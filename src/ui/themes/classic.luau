local palette = require('../../framework/config/ui/colors').text

return {
    DisplayName = 'Classic',
    Font = {
        Normal = Enum.Font.BuilderSans,
        Medium = Enum.Font.BuilderSansMedium,
        Bold = Enum.Font.BuilderSansBold,
        ExtraBold = Enum.Font.BuilderSansExtraBold,
        MonoSpace = Enum.Font.RobotoMono,
    },
    Colors = {
        Background = Color3.fromRGB(36, 36, 37),
        Primary = Color3.fromRGB(88, 101, 242),
        OnPrimary = Color3.fromRGB(61, 67, 135),
        Stroke = Color3.fromRGB(45, 45, 45),
        Error = palette.red,
        Icons = Color3.fromRGB(232, 233, 235),
        ScrollBar = {
            Thumb = Color3.fromRGB(78, 78, 79),
            Arrow = Color3.fromRGB(232, 233, 235),
            Background = Color3.fromRGB(26, 26, 26),
        },
        Buttons = {
            Holding = Color3.fromRGB(78, 78, 79),
            Default = Color3.fromRGB(46, 46, 47),
        },
        Border = {
            Holding = Color3.fromRGB(60, 60, 60),
            Default = Color3.fromRGB(38, 38, 38),
        },
        Text = {
            Default = palette.green,
            Dark = palette.purple,
            Darker = palette.red,
        },
        Slider = {
            SliderBar = Color3.fromRGB(1, 76, 105),
            SliderNumber = palette.green,
        },
    },
}
