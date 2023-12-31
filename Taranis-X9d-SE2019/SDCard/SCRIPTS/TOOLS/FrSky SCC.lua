--[[
        ChgId

      DanielGeA

  License https://www.gnu.org/licenses/gpl-3.0.en.html

  Ported from erskyTx. Thanks to MikeB

  Lua script for radios X7, X9, X-lite and Horus with openTx 2.2 or higher

  Change Frsky sensor Id

]]--

local version = '0.3.1'
local refresh = 0
local lcdChange = true
local readIdState = 40 -- 0-9 stop sensors, 10-19 request id, 20-29 read id, 30-39 restart sensors, 40 ok
local sendIdState = 30 -- 0-9 stop sensors, 10-19 send id, 20-29 restart sensors, 30 ok
local tsReadId = 0
local tsSendId = 0
local sensorIdTx = 17 -- sensorid 18
local sensor = {sensorType = {selected = 12, list = {'Vario', 'FAS-40S', 'FLVSS', 'RPM', 'Fuel', 'Accel', 'GPS', 'Air speed', 'R Bus', 'Gas suit', 'X8R2ANA', '-'}, dataId = { 0x100, 0x200, 0x300, 0x500, 0x600, 0x700, 0x800, 0xA00, 0xB00, 0xD00, 0xF103 }, elements = 11 },
                sensorId = {selected = 29, elements = 28}}
local selection = {selected = 1, state = false, list = {'sensorType', 'sensorId'}, elements = 2}

local function getFlags(element)
  if selection.selected ~= element then return 0 end
  if selection.selected == element and selection.state == false then return 0 + INVERS end
  if selection.selected == element and selection.state == true then return 0 + INVERS + BLINK end
  return
end

local function increase(data)
  data.selected = data.selected + 1
  if data.selected > data.elements then data.selected = 1 end
end

local function decrease(data)
  data.selected = data.selected - 1
  if data.selected < 1 then data.selected = data.elements end
end

local function readId()
  if readIdState == 0 then tsReadId = getTime() end
  -- stop sensors
  if readIdState < 10 then
    sportTelemetryPush(sensorIdTx, 0x21, 0xFFFF, 0x80)
    readIdState = readIdState + 10
  -- request id
  elseif readIdState < 20 then
    sportTelemetryPush(sensorIdTx, 0x30, sensor.sensorType.dataId[sensor.sensorType.selected], 0x01)
    readIdState = readIdState + 10
  -- read id
  elseif readIdState < 30 then
    local physicalId, primId, dataId, value = sportTelemetryPop() -- frsky/lua: phys_id/sensor id, type/frame_id, sensor_id/data_id
    if primId == 0x32 and dataId == sensor.sensorType.dataId[sensor.sensorType.selected] then
      if bit32.band(value, 0xFF) ==  1 then
        sensor.sensorId.selected = ((value - 1) / 256) + 1
        readIdState = 30
      end
    end
  -- restart sensors
  elseif readIdState < 40 then
    sportTelemetryPush(sensorIdTx, 0x20, 0xFFFF, 0x80)
    readIdState = readIdState + 10
  end
  -- update lcd
  if readIdState == 40 then lcdChange = true end
end

local function sendId()
  -- stop sensors
  if sendIdState < 10 then
    sportTelemetryPush(sensorIdTx, 0x21, 0xFFFF, 0x80)
    sendIdState = sendIdState + 10
  -- send id
  elseif sendIdState < 20 then
    sportTelemetryPush(sensorIdTx, 0x31, sensor.sensorType.dataId[sensor.sensorType.selected], 0x01 + (sensor.sensorId.selected - 1) * 256)
    sendIdState = sendIdState + 10
  -- restart sensors
  elseif sendIdState < 30 then
    sportTelemetryPush(sensorIdTx, 0x20, 0xFFFF, 0x80)
    sendIdState = sendIdState + 10
  end
  -- update lcd
  if sendIdState == 30 then lcdChange = true end
end

local function init_func()
end

local function bg_func(event)
  if refresh < 5 then refresh = refresh + 1 end
end

local function refreshHorus()
  lcd.clear()
  lcd.drawRectangle(90, 40, 300, 160)
  lcd.drawText(180,50, 'FrSky SCC v' .. version, 0 + INVERS)
  lcd.drawText(110, 90, 'Capteur', 0)
  lcd.drawText(110, 110, 'Capteur Id', 0)
  lcd.drawText(250, 90, sensor.sensorType.list[sensor.sensorType.selected], getFlags(1))
  if sensor.sensorId.selected ~= sensor.sensorId.elements + 1 then
    lcd.drawText(250, 110, sensor.sensorId.selected, getFlags(2))
  else
    lcd.drawText(250, 110, '-', getFlags(2))
  end
  if readIdState < 40 then lcd.drawText(110, 140, 'Lecture Id...', 0 + INVERS) end
  if sendIdState < 30 then lcd.drawText(110, 140, 'Mise a jour Id...', 0 + INVERS) end
  lcd.drawText(100, 170, 'Appui long sur [ENTER] pour valider', 0 + INVERS)
end

local function refreshTaranis()
  lcd.clear()
  lcd.drawScreenTitle('FrSky SCC v' .. version, 1, 1)
  lcd.drawText(1, 11, 'Capteur', 0)
  lcd.drawText(1, 21, 'Capteur Id', 0)
  lcd.drawText(60, 11, sensor.sensorType.list[sensor.sensorType.selected], getFlags(1))
  if sensor.sensorId.selected ~= sensor.sensorId.elements + 1 then
    lcd.drawText(60, 21, sensor.sensorId.selected, getFlags(2))
  else
    lcd.drawText(60, 21, '-', getFlags(2))
  end
  if readIdState < 40 then lcd.drawText(1, 35, 'Lecture Id...', 0 + INVERS) end
  if sendIdState < 30 then lcd.drawText(1, 35, 'Mise a jour Id...', 0 + INVERS) end
  if LCD_W == 212 then 
    lcd.drawText(1, 46, 'Appui long sur [ENTER] ou [MENU] pour valider', SMLSIZE)
  else
    lcd.drawText(1, 46, 'Appui long sur [ENTER]', SMLSIZE)
    lcd.drawText(1, 54, 'ou [MENU] pour valider', SMLSIZE)
  end
end

local function run_func(event)
  if refresh == 5 or lcdChange == true or selection.state == true then
    if LCD_W == 480 then refreshHorus() else refreshTaranis() end
    lcdChange = false
  end

-- left = up/decrease right = down/increase
  if selection.state == false then
    if event == EVT_ROT_LEFT or event == EVT_MINUS_BREAK or event == EVT_DOWN_BREAK then
      decrease(selection)
      lcdChange = true
    end
    if event == EVT_ROT_RIGHT or event == EVT_PLUS_BREAK or event == EVT_UP_BREAK then
      increase(selection)
      lcdChange = true
    end
  end
  if selection.state == true then
    if event == EVT_ROT_LEFT or event == EVT_MINUS_BREAK or event == EVT_DOWN_BREAK then
      if selection.selected == 1 then
        sensor.sensorId.selected = sensor.sensorId.elements + 1
      end
      decrease(sensor[selection.list[selection.selected]])
      if sensor.sensorId.selected - 1 == sensorIdTx then decrease(sensor[selection.list[selection.selected]]) end
      lcdChange = true
    end
    if event == EVT_ROT_RIGHT or event == EVT_PLUS_BREAK or event == EVT_UP_BREAK then
      if selection.selected == 1 then
        sensor.sensorId.selected = sensor.sensorId.elements + 1
      end
      increase(sensor[selection.list[selection.selected]])
      if sensor.sensorId.selected -1 == sensorIdTx then increase(sensor[selection.list[selection.selected]]) end
      lcdChange = true
    end
  end
  if event == EVT_ENTER_BREAK and sendIdState == 30 then
    selection.state = not selection.state
    if selection.selected == 1 and sensor.sensorId.selected == sensor.sensorId.elements + 1 and sensor.sensorType.selected ~= sensor.sensorType.elements + 1 and selection.state == false then
      readIdState = 0
    end
    lcdChange = true
  end
  if event == EVT_EXIT_BREAK then
    if selection.selected == 1 and sensor.sensorId.selected == sensor.sensorId.elements + 1 and sensor.sensorType.selected ~= sensor.sensorType.elements + 1 and selection.state == true then
      readIdState = 0
    end
    selection.state = false
    lcdChange = true
  end
  if event == EVT_ENTER_LONG or event == EVT_MENU_LONG then
    -- killEvents(EVT_ENTER_LONG) -- not working
    if sensor.sensorId.selected ~= sensor.sensorId.elements + 1 and sensor.sensorType.selected ~= sensor.sensorType.elements + 1  then
      sendIdState = 0
      lcdChange = true
    end
  end
  if sportTelemetryPush() == true then
    if readIdState < 40 then readId() end
    if sendIdState < 30 then sendId() end
  end
  if readIdState < 40 and getTime() - tsReadId > 100 then readIdState = 40 end
  refresh = 0
  return 0
end

return {run=run_func, background=bg_func, init=init_func}
