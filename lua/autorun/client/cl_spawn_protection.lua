local textColor = Color( 255, 235, 20, 255 )
local boxColor = Color( 0, 0, 0, 76 )
local TEXT_ALIGN_CENTER = TEXT_ALIGN_CENTER

local scrw = ScrW()
local scrh = ScrH()

surface.CreateFont( "SpawnProtection", {
    font = "Verdana",
    size = ScreenScale( 15 ),
    weight = 400,
} )

local text = "Spawn protection enabled"

local function drawNotice()
    local active = LocalPlayer():GetNWBool( "HasSpawnProtection", false )
    if not active then return end

    draw.RoundedBox( 10, scrw * 0.355, scrh * 0.9, scrw * 0.29, scrh * 0.075, boxColor )
    draw.SimpleText( text, "SpawnProtection", scrw * 0.5, scrh * 0.936, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
end

hook.Add( "HUDPaint", "DrawSpawnProtection", drawNotice )
