-- ######### 切换输入法
local function Chinese()
    -- 简体拼音，如果你的输入法不是鼠须管，把下面 ctrl+command+. 注释打开，看看自己输入法的 source id 是多少
    hs.keycodes.currentSourceID("im.rime.inputmethod.Squirrel.Hans") 
end

local function English()
    -- ABC
    hs.keycodes.currentSourceID("com.apple.keylayout.ABC")
end

-- 配置：app 和对应的输入法
local app2Ime = {
    {'/System/Library/CoreServices/Finder.app', 'English'},
    {'/Applications/Visual Studio Code.app', 'English'},
    {'/Applications/Xcode.app', 'English'},
    {'/Applications/Google Chrome.app', 'English'},
    {'/Applications/Kindle.app', 'English'},
    {'/Applications/System Preferences.app', 'English'},
    {'/Applications/Arc.app', 'English'},
    {'/Applications/AxFinder.app', 'English'},
    {'/Applications/Figma.app', 'English'},
    {'/Applications/Fork.app', 'English'},
    {'/Applications/Hammerfall.app', 'English'},
    {'/Applications/Lookin.app', 'English'},
    {'/Applications/Warp.app', 'English'},
    {'/Applications/iTerm.app', 'English'},
    {'/Applications/Proxyman.app', 'English'},
    {'/Applications/企业微信.app', 'Chinese'},
    {'/Applications/WeChat.app', 'Chinese'},
    {'/Applications/QQ.app', 'Chinese'},
    {'/Applications/Obsidian.app', 'Chinese'},
}

-- 切换输入法
function updateFocusAppInputMethod()
    local ime = 'English'
    local focusAppPath = hs.window.frontmostWindow():application():path()
    for index, app in pairs(app2Ime) do
        local appPath = app[1]
        local expectedIme = app[2]

        if focusAppPath == appPath then
            ime = expectedIme
            break
        end
    end

    if ime == 'English' then
        English()
    else
        Chinese()
    end
end

-- 当选中某窗口按下 ctrl+command+. 时会显示应用的路径、输入法 id 信息
-- hs.hotkey.bind({'ctrl', 'cmd'}, ".", function()
--     hs.alert.show("App path:        "
--     ..hs.window.focusedWindow():application():path()
--     .."\n"
--     .."App name:      "
--     ..hs.window.focusedWindow():application():name()
--     .."\n"
--     .."IM source id:  "
--     ..hs.keycodes.currentSourceID())
-- end)



-- ######### 快捷键切换 app
-- 配置：app 和对应的快捷键
-- 参数 1 mode 键，可填写: command,control,option,shift
-- 参数 2 key 键，如果需要绑定特殊按键，如上下左右，参考：https://www.hammerspoon.org/docs/hs.keycodes.html#map
-- 参数 3 需要激活 app 的路径
local app2key = {
    {{'option'}, "1", '/Applications/Xcode.app'},
    {{'option'}, "2", '/Applications/Arc.app'},
    {{'option'}, "3", '/System/Library/CoreServices/Finder.app'},
    {{'option'}, "4", '/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app'},
    {{'shift', 'command'}, "1", '/Applications/Lookin.app'},
    {{'shift', 'command'}, "2", '/Applications/Figma.app'},
    {{'shift', 'option'}, "1", '/Applications/Warp.app'},
    {{'shift', 'option'}, "2", '/Applications/Proxyman.app'},
    {{'shift', 'option'}, "3", '/Applications/Fork.app'}
}

for index, obj in pairs(app2key) do
    hs.hotkey.bind(obj[1], obj[2], function()
        hs.application.launchOrFocus(obj[3])
    end)
end



-- ######### 鼠标根据 app 移动，配合快捷键切换 app 使用，适用于多个屏幕

local function class(className, super)
    -- 构建类
    local clazz = { __cname = className, super = super }
    if super then
        -- 设置类的元表，此类中没有的，可以查找父类是否含有
        setmetatable(clazz, { __index = super })
    end
    -- new 方法创建类对象
    clazz.new = function(...)
        -- 构造一个对象
        local instance = {}
        -- 设置对象的元表为当前类，这样，对象就可以调用当前类生命的方法了
        setmetatable(instance, { __index = clazz })
        if clazz.ctor then
            clazz.ctor(instance, ...)
        end
        return instance
    end
    return clazz
end

local MouseObject = class("MouseObject")
MouseObject.static = 'Static MouseObject'
function MouseObject:ctor(appName, screenID, points, windowID)
    self.appName = appName or nil
    self.screenID = screenID or nil
    self.points = points or nil
    self.windowID = windowID or nil
end

-- [appName: object]
local mouse_object = {}

-- 由于 applicationWatcher 会先触发 activated 再触发 deactivated，所以需要在 activated 的时候记录离开时的坐标
local deactivatedPoints = nil 
local deactivatedScreen = nil

-- 判断 mouse_object 中是否存在 appName 对应的对象
function containsAppName(appName)
    for _, obj in pairs(mouse_object) do
        if obj.appName == appName then
            return true
        end
    end
    return false
end

-- 更新鼠标位置
function updateMouse(appName)
    deactivatedPoints = hs.mouse.absolutePosition()
    deactivatedScreen = hs.mouse.getCurrentScreen():id()
    
    local focusedWindow = hs.window.focusedWindow()
    local targetAppCenter = hs.window.focusedWindow():frame().center

    -- 如果 app 还未记录上一次鼠标位置，且 app 窗口和当前鼠标窗口不在一起，则移动到 app 窗口中间
    if (containsAppName(appName) == false) then
        mouse_object[appName] = MouseObject.new(appName, deactivatedScreen, deactivatedPoints, hs.window.focusedWindow():id())
        if (focusedWindow:screen():id() == hs.mouse.getCurrentScreen():id()) then
            -- 不处理
        else
            hs.mouse.absolutePosition(targetAppCenter)
        end
    end
    
    for key, value in pairs(mouse_object) do
        if key == appName then
            mouse_object[appName].windowID = hs.window.focusedWindow():id()
            -- 如果 app 窗口和当前鼠标窗口在一起，则不处理
            if (focusedWindow:screen():id() == hs.mouse.getCurrentScreen():id()) then
                -- 不处理
            else
                -- 如果 app 窗口 和 上次记录的窗口 一致则移动，否则移动到 app 窗口中间
                if (focusedWindow:screen():id() == mouse_object[appName].screenID) then
                    hs.mouse.absolutePosition(mouse_object[appName].points)
                else
                    mouse_object[appName].screenID = focusedWindow:screen():id()
                    hs.mouse.absolutePosition(targetAppCenter)
                end
            end
        end
    end


end


-- ######### Main
-- 窗口激活
function applicationWatcher(appName, eventType, appObject)
    if (eventType == hs.application.watcher.activated or eventType == hs.application.watcher.launched) then
        updateFocusAppInputMethod()
        updateMouse(appName)
    end
    
    if (eventType == hs.application.watcher.deactivated) then 
        if mouse_object[appName] then 
            -- 离开 app 时如果 鼠标和 app 在同一个屏幕，记录鼠标位置
            local targetWindow = hs.window.get(mouse_object[appName].windowID)
            if targetWindow then
                -- hs.alert.show(appName..targetWindow:title()..targetWindow:screen():id()..deactivatedScreen)
                if (targetWindow:screen():id() == deactivatedScreen) then
                    mouse_object[appName].points = deactivatedPoints
                end
                mouse_object[appName].screenID = targetWindow:screen():id()
            end
        else
            mouse_object[appName] = MouseObject.new(appName, deactivatedScreen, deactivatedPoints, nil)
        end
    end
end

appWatcher = hs.application.watcher.new(applicationWatcher)
appWatcher:start()