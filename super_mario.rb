
require './config.rb'
require 'gosu'
require 'pp'
require './lib/maplib.rb'

class GameWindow < Gosu::Window
  def initialize
    super(WIDTH, HEIGHT, false)
    @map =  load_map_from_json('assets\Mario World.json')
    @x = @y = 0
    @speed = 16
  end

  def update
    @x -= @speed if button_down?(Gosu::KbLeft)
    @x += @speed if button_down?(Gosu::KbRight)
    @y -= @speed if button_down?(Gosu::KbUp)
    @y += @speed if button_down?(Gosu::KbDown)
  end

  def screen_width_in_tiles
    (self.width / @map.tilewidth.to_f).ceil
  end

  def screen_height_in_tiles
    (self.height / @map.tileheight.to_f).ceil
  end

  def transpose_tile_x(x, off_x)
    x * @map.tilewidth - off_x
  end

  def transpose_tile_y(y, off_y)
    y * @map.tileheight - off_y
  end

  def draw_tiles(layer, x, y)
    off_x = x / @map.tilewidth
    off_y = y / @map.tilewidth

    tile_range_x = (off_x..screen_width_in_tiles + off_x)
    tile_range_y = (off_y..screen_height_in_tiles + off_y)
    tile_range_y.each do |yy|
      tile_range_x.each do |xx|
        tile = tile_at(layer, xx, yy)
        if(tile != 0 && tile != nil)
          target_x = transpose_tile_x(xx, x)
          target_y = transpose_tile_y(yy, y)
          tileset = @map.tilesets.fetch(1) # only have one tileset for now
          image = tileset.tiles[tile-1]
          image.draw(target_x,target_y, 0)
          end
      end
    end
  end

  def draw_layer(layer, offset_x, offset_y)
    if layer.type == 'tilelayer'
      draw_tiles(layer, offset_x, offset_y)
    elsif layer.type == 'objectgroup'
      # draw_objects(offset_x, offset_y, tilesets)
    end
  end

  def draw_map
    @map.layers.each do |layer|
      draw_layer(layer, @x, @y)
    end
  end

  def draw
    draw_map
  end
end

GameWindow.new.show