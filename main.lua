function love.load()
  love.graphics.setBackgroundColor(0.96, 0.94, 0.86) -- paper tone
end

function love.draw()
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.print("Spite Driven Development", 40, 40)
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  end
end
