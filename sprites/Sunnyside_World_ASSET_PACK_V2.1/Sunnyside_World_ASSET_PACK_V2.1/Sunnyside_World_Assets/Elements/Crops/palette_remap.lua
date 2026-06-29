-- ============================================================
--  palette_remap.lua
--  Batch palette-swap + trim for every PNG in a folder.
--
--  HOW TO USE:
--    Option A (GUI): File > Scripts > Run Script... > pick this file
--    Option B (headless bat):
--        Aseprite.exe -b --script palette_remap.lua
--
--  WHAT IT DOES:
--    * Loads the target palette from PALETTE_FILE (an .aseprite file).
--    * Reads every .png in the SAME FOLDER as this script.
--    * Opens each file as a BRAND-NEW sprite object — bypasses the
--      "open as animation sequence" dialog entirely.
--    * Converts to RGBA so pixels can be read/written freely.
--    * Remaps every opaque pixel to the nearest color in the loaded palette
--      (Euclidean distance in RGB space).
--    * Trims transparent edges so the canvas fits content exactly.
--    * Saves to an "output/" sub-folder, original files are untouched.
-- ============================================================

-- ============================================================
--  STAR  CONFIGURE YOUR PALETTE FILE HERE  STAR
--
--  Point PALETTE_FILE at any .aseprite (or .png) file whose
--  palette you want to use as the target.  Every color entry
--  in that file's first palette will be loaded automatically.
--  Fully transparent pixels are never remapped.
-- ============================================================
local PALETTE_FILE = "E:\\Code\\avatar-game-online\\sprites\\Sprout Lands color pallet\\Sprout Lands defautlt palette.aseprite"

-- ============================================================
--  CONFIGURATION  (change if needed)
-- ============================================================
local OUTPUT_SUBDIR   = "output"   -- sub-folder name for exported files
local ALPHA_THRESHOLD = 128        -- pixels with alpha < this stay transparent

-- Populated at startup by loadPalette() — do not edit manually
local TARGET_PALETTE = {}

-- ============================================================
--  LOAD PALETTE FROM FILE
-- ============================================================
local function loadPalette()
    if not app.fs.isFile(PALETTE_FILE) then
        app.alert("Palette file not found:\n" .. PALETTE_FILE)
        return false
    end

    -- Open the palette source as a temporary sprite
    local palSpr = Sprite{ fromFile = PALETTE_FILE }
    if not palSpr then
        app.alert("Could not open palette file:\n" .. PALETTE_FILE)
        return false
    end

    local pal = palSpr.palettes[1]
    local count = 0

    for i = 0, #pal - 1 do
        local color = pal:getColor(i)
        -- Skip fully-transparent entries (e.g. index 0 in indexed palettes)
        if color.alpha >= ALPHA_THRESHOLD then
            TARGET_PALETTE[#TARGET_PALETTE + 1] = {
                r = color.red,
                g = color.green,
                b = color.blue,
            }
            count = count + 1
        end
    end

    palSpr:close()

    if count == 0 then
        app.alert("Palette file contained no opaque colors:\n" .. PALETTE_FILE)
        return false
    end

    print(string.format("[Palette] Loaded %d colors from: %s", count, PALETTE_FILE))
    return true
end

-- ============================================================
--  INTERNAL HELPERS
-- ============================================================

-- Squared Euclidean distance in RGB space (fast, no sqrt needed)
local function colorDistSq(r1,g1,b1, r2,g2,b2)
    local dr,dg,db = r1-r2, g1-g2, b1-b2
    return dr*dr + dg*dg + db*db
end

-- Return the app.pixelColor RGBA value of the nearest palette entry
local function nearestColor(r, g, b)
    local bestDist = math.huge
    local best = TARGET_PALETTE[1]
    for _, c in ipairs(TARGET_PALETTE) do
        local d = colorDistSq(r,g,b, c.r,c.g,c.b)
        if d < bestDist then
            bestDist = d
            best = c
        end
    end
    return app.pixelColor.rgba(best.r, best.g, best.b, 255)
end

-- Compute the bounding box of non-transparent pixels.
-- Returns {x,y,w,h} or nil if the image is fully transparent.
local function getTrimRect(image)
    local W, H   = image.width, image.height
    local minX   = W
    local minY   = H
    local maxX   = -1
    local maxY   = -1

    for py = 0, H-1 do
        for px = 0, W-1 do
            local a = app.pixelColor.rgbaA(image:getPixel(px, py))
            if a >= ALPHA_THRESHOLD then
                if px < minX then minX = px end
                if py < minY then minY = py end
                if px > maxX then maxX = px end
                if py > maxY then maxY = py end
            end
        end
    end

    if maxX < 0 then return nil end
    return { x=minX, y=minY, w=(maxX-minX+1), h=(maxY-minY+1) }
end

-- Return the directory that contains this script file
local function scriptDir()
    local path = debug.getinfo(1,"S").source:sub(2)  -- strip leading '@'
    return app.fs.filePath(path)
end

-- Create directory if it does not exist
local function ensureDir(dir)
    if not app.fs.isDirectory(dir) then
        app.fs.makeDirectory(dir)
    end
end

-- ============================================================
--  MAIN
-- ============================================================
local function main()
    -- ── Load the target palette first ────────────────────────────────────
    if not loadPalette() then return end

    local baseDir   = scriptDir()
    local outputDir = app.fs.joinPath(baseDir, OUTPUT_SUBDIR)
    ensureDir(outputDir)

    -- Collect .png files in baseDir (skip the output sub-folder)
    local allFiles = app.fs.listFiles(baseDir)
    local pngFiles = {}
    for _, name in ipairs(allFiles) do
        if name:lower():match("%.png$") then
            pngFiles[#pngFiles+1] = name
        end
    end

    if #pngFiles == 0 then
        app.alert("No .png files found in:\n" .. baseDir)
        return
    end

    local processed, skipped = 0, 0

    for _, filename in ipairs(pngFiles) do
        local srcPath = app.fs.joinPath(baseDir, filename)
        local dstPath = app.fs.joinPath(outputDir, filename)

        -- ── Open as a brand-new Sprite (bypasses sequence detection) ──────
        local spr = Sprite{ fromFile = srcPath }
        if not spr then
            print("[SKIP] Could not open: " .. filename)
            skipped = skipped + 1
            goto continue
        end

        -- ── Convert to RGBA ───────────────────────────────────────────────
        app.command.ChangePixelFormat{ format="rgb", dithering="none" }

        -- ── Remap pixels ──────────────────────────────────────────────────
        local cel   = spr.cels[1]
        local image = cel.image:clone()

        for py = 0, image.height-1 do
            for px = 0, image.width-1 do
                local pixel = image:getPixel(px, py)
                local a     = app.pixelColor.rgbaA(pixel)
                if a >= ALPHA_THRESHOLD then
                    local r = app.pixelColor.rgbaR(pixel)
                    local g = app.pixelColor.rgbaG(pixel)
                    local b = app.pixelColor.rgbaB(pixel)
                    image:putPixel(px, py, nearestColor(r,g,b))
                else
                    image:putPixel(px, py, app.pixelColor.rgba(0,0,0,0))
                end
            end
        end

        -- Write remapped image back into the cel
        cel.image = image

        -- ── Trim to content ───────────────────────────────────────────────
        local rect = getTrimRect(image)
        local sizeNote = "(blank - skipped trim)"
        if rect then
            spr:crop(rect.x, rect.y, rect.w, rect.h)
            sizeNote = rect.w .. "x" .. rect.h
        end

        -- ── Export to output/ ─────────────────────────────────────────────
        spr:saveCopyAs(dstPath)

        -- ── Close without touching the original ───────────────────────────
        spr:close()

        processed = processed + 1
        print(string.format("[OK] %-40s → %s", filename, sizeNote))

        ::continue::
    end

    local msg = string.format(
        "Done!\n%d processed, %d skipped.\n\nOutput folder:\n%s",
        processed, skipped, outputDir)
    print(msg)
    app.alert(msg)
end

main()
