require './config.rb'
require 'gosu'
require 'gosu_tiled'
require 'pp'

class GameWindow < Gosu::Window
  def initialize
    super(WIDTH, HEIGHT, false)
    @map = Gosu::Tiled.load_json(self, 'Mario World.json')
    pp  @map.layers.object.select { |l| puts l.instance_variables }
    # player_pos_x = @map.layers.object.select { |l| l.data.name == 'Players' }.select{ |p| p.name = 'player1' }
    # puts(player_pos_x)
    @x = @y = 0
    @speed = 3
  end

  def update
    @x -= @speed if button_down?(Gosu::KbLeft)
    @x += @speed if button_down?(Gosu::KbRight)
    @y -= @speed if button_down?(Gosu::KbUp)
    @y += @speed if button_down?(Gosu::KbDown)
  end

  def draw
    @map.draw(@x, @y)
  end
end

GameWindow.new.show