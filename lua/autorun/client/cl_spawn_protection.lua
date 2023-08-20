local textColor = Color( 0, 100, 255 )
local outlineColor = color_black
local TEXT_ALIGN_CENTER = TEXT_ALIGN_CENTER

local scrw = ScrW()
local scrh = ScrH()

surface.CreateFont( "SpawnProtection", {
    font = "Roboto",
    size = ScreenScale( 15 ),
    weight = 600,
} )

local function drawNotice()
    local active = LocalPlayer():GetNWBool( "HasSpawnProtection", false )
    if not active then return end

    draw.SimpleTextOutlined( "Spawn protection enabled", "SpawnProtection", scrw * 0.5, scrh * 0.9, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, outlineColor )
end

hook.Add( "HUDPaint", "DrawSpawnProtection", drawNotice )
