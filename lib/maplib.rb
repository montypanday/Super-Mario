require 'json'
require 'gosu'

class TiledObject
  attr_reader :id, :name, :width, :height, :x, :y, :rotation, :type, :visible
  def initialize(object)
    pp object
    @id = object['id']
    @name = object.name
    @width = object.width
    @height = object.height
    @x = object.x
    @y = object.y
    @rotation = object.rotation
    @type = object.type
    @visible = object.visible
  end
end

class Layer
  attr_reader :draworder, :data, :height, :id, :name, :opacity, :type, :visible, :width, :x, :y

  def initialize(layer)
    @draworder = layer['draworder']
    @data = layer['data']
    @height = layer['height']
    @id = layer['id']
    @name = layer['name']
    @opacity = layer['opacity']
    @type = layer['type']
    @visible = layer['visible']
    @width = layer['width']
    @x = layer['x']
    @y = layer['y']

  end
end

class Layers
  include Enumerable

  def initialize(data)
    @layers = data.map do |layer|
      Layer.new(layer)
    end
  end

  def tile
    @layers.select { |l| l.type == 'tilelayer' }.select(&:visible?)
  end

  def object
    @layers.select { |l| l.type == 'objectgroup' }.select(&:visible?)
  end

  def size
    @layers.size
  end

  def each(&block)
    @layers.each do |layer|
      if block_given?
        block.call(layer)
      else
        yield layer
      end
    end
  end
end

class Tileset
  attr_reader :columns, :firstgid, :image, :imageheight, :imagewidth, :margin, :name, :spacing, :tilecount, :tileheight, :tilewidth, :tiles
  def initialize tileset
    @columns = tileset['columns']
    @firstgid = tileset['firstgid']
    @image = tileset['image']
    @imageheight = tileset['imageheight']
    @imagewidth = tileset['imagewidth']
    @margin = tileset['margin']
    @name = tileset['name']
    @spacing = tileset['spacing']
    @tilecount = tileset['tilecount']
    @tileheight = tileset['tileheight']
    @tilewidth = tileset['tilewidth']
    @tiles = Gosu::Image.load_tiles(
        File.join(ASSETS_DIR, @image), @tilewidth ,@tileheight, retro: false, tileable: true
    )
  end
end

class Map
  attr_reader :width, :height, :tilewidth, :tileheight, :layers, :tilesets

  def initialize(data)
    @width = data['width']
    @height = data['height']
    @tileheight = data['tileheight']
    @tilewidth = data['tilewidth']
    @layers = Layers.new(data['layers'])
    @tilesets = {}
    data['tilesets'].each do |t|
      @tilesets[t['firstgid']] = Tileset.new(t)
    end
  end
end

def load_map_from_json(file_path)
  file = File.read(file_path)
  data = JSON.parse(file)
  Map.new(data)
end

# provide x and y to get tile from layer
# 2 dimensional grid is stored as single array
def tile_at(layer, x, y)
  return layer.data[y * layer.width + x]
end