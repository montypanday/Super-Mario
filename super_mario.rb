
require './config.rb'
require 'gosu'
require 'pp'
require './lib/maplib.rb'

class GameWindow < Gosu::Window
  def initialize
    super(WIDTH, HEIGHT, false)
    @map =  load_map_from_json('assets\Mario World.json')
    @x = @y = 0
    @speed = 3
  end

  def update
    @x -= @speed if button_down?(Gosu::KbLeft)
    @x += @speed if button_down?(Gosu::KbRight)
    @y -= @speed if button_down?(Gosu::KbUp)
    @y += @speed if button_down?(Gosu::KbDown)
  end

  def draw_tiles(layer, offset_x, offset_y, tilesets)
    x_range = (0..(@map.width-1))
    y_range = (0..(@map.height-1))
    y_range.each do |yy|
      x_range.each do |xx|
        tile = tile_at(layer, xx, yy)
        if(tile != 0 && tile != nil)
          tileset = @map.tilesets.fetch(1)
          image = tileset.tiles[tile-1]
          image.draw(xx * @map.tilewidth, yy * @map.tileheight, 0)
          end
      end
    end
  end

  def draw_layer(layer, offset_x, offset_y, tilesets)
    if layer.type == 'tilelayer'
      draw_tiles(layer, offset_x, offset_y, tilesets)
    elsif layer.type == 'objectgroup'
      # draw_objects(offset_x, offset_y, tilesets)
    end
  end

  def draw_map
    @map.layers.each do |layer|
      draw_layer(layer, @x, @y, @map.tilesets)
    end
  end

  def draw
    draw_map
  end
end

GameWindow.new.show