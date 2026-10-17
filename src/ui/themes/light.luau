local palette = require('../../framework/config/ui/colors').text

return {
    DisplayName = 'Light',
    Font = {
        Normal = Enum.Font.BuilderSans,
        Medium = Enum.Font.BuilderSansMedium,
        Bold = Enum.Font.BuilderSansBold,
        ExtraBold = Enum.Font.BuilderSansExtraBold,
        MonoSpace = Enum.Font.RobotoMono,
    },
    Colors = {
        Background = Color3.fromRGB(243, 243, 245),
        Primary = Color3.fromRGB(88, 101, 242),
        OnPrimary = Color3.fromRGB(214, 218, 253),
        Stroke = Color3.fromRGB(212, 212, 218),
        Error = palette.red,
        Icons = Color3.fromRGB(40, 40, 48),
        ScrollBar = {
            Thumb = Color3.fromRGB(190, 190, 198),
            Arrow = Color3.fromRGB(60, 60, 70),
            Background = Color3.fromRGB(226, 226, 230),
        },
        Buttons = {
            Holding = Color3.fromRGB(218, 218, 226),
            Default = Color3.fromRGB(231, 231, 237),
        },
        Border = {
            Holding = Color3.fromRGB(180, 180, 192),
            Default = Color3.fromRGB(208, 208, 216),
        },
        Text = {
            Default = palette.green,
            Dark = palette.purple,
            Darker = palette.red,
        },
        Slider = {
            SliderBar = Color3.fromRGB(120, 130, 240),
            SliderNumber = palette.green,
        },
    },
}
