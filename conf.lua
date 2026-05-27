function love.conf(t)
  t.identity = "spite-driven-development"
  t.version = "11.5"
  t.console = false

  t.window.title = "Spite Driven Development"
  t.window.width = 1280
  t.window.height = 800
  t.window.resizable = true
  t.window.minwidth = 960
  t.window.minheight = 720
  t.window.vsync = 1
  t.window.msaa = 0

  -- Disable modules we don't need yet to shave startup time.
  t.modules.joystick = false
  t.modules.physics = false
  t.modules.video = false
  t.modules.touch = false
end
