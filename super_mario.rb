require 'gosu'
require 'pp'
require 'json'

WIDTH = 800
HEIGHT = 256
ASSETS_DIR = 'assets'
VELOCITY = 2
SPEED = 1.5

ROUND_CONFIG = 'assets/rounds.json'

ENEMY_GOOMBA_SPEED = 1


# Classes
class TiledObject
  attr_reader :id, :name, :width, :height, :x, :y, :rotation, :type, :visible, :properties

  def initialize(object)
    @id = object['id']
    @name = object['name']
    @width = object['width']
    @height = object['height']
    @x = object['x']
    @y = object['y']
    @rotation = object['rotation']
    @type = object['type']
    @visible = object['visible']
    @properties = []
    if object['properties']
      for custom_property in object['properties']
        @properties << TiledObjectProperty.new(custom_property)
      end
    end
  end
end

class TiledObjectProperty
  attr_reader :name, :type, :value

  def initialize(object)
    @name = object['name']
    @type = object['type']
    @value = object['value']
  end
end

class Layer
  attr_reader :draworder, :data, :height, :id, :name, :opacity, :type, :visible, :width, :x, :y, :tiledobjects

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
    @tiledobjects = []

    if (layer['objects'] != nil)
      layer['objects'].each do |t|
        @tiledobjects << TiledObject.new(t)
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
        File.join(ASSETS_DIR, @image), @tilewidth, @tileheight, retro: false, tileable: true
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
    @layers = data['layers'].map do |layer|
      Layer.new(layer)
    end
    @tilesets = {}
    data['tilesets'].each do |t|
      @tilesets[t['firstgid']] = Tileset.new(t)
    end
  end
end

class Player
  attr_accessor :x, :y, :dir, :vy, :standing, :walk1, :walk2, :jump, :cur_image, :width, :height

  def initialize(x, y)
    @x = x
    @y = y
    @width = 16
    @height = 16
    @vy = 0
    @dir = :right
    filename = "assets/NES - Super Mario Bros - Mario & Luigi.png"
    @standing = Gosu::Image.new(filename).subimage(80, 34, @width, @height)
    @walk1 = Gosu::Image.new(filename).subimage(97, 34, @width, @height)
    @walk2 = Gosu::Image.new(filename).subimage(114, 34, @width, @height)
    @jump = Gosu::Image.new(filename).subimage(148, 34, @width, @height)
    # # This always points to the frame that is currently drawn.
    # # This is set in update, and used in draw.
    @cur_image = @standing
  end
end

class Enemy
  attr_accessor :x, :y, :dir, :vy, :standing, :walk1, :walk2, :squished, :cur_image, :width, :height

  def initialize(tiledobject)
    @x = tiledobject.x
    @y = tiledobject.y
    @dir = tiledobject.properties.select{|property| property.name == "dir"}.first.value
    @vy = 0
    @width = 16
    @height = 16
    @type = tiledobject.type
    filename = "assets/NES - Super Mario Bros - Enemies & Bosses.png"
    @standing = Gosu::Image.new(filename).subimage(0, 16, @width, @height)
    @walk1 = Gosu::Image.new(filename).subimage(0, 16, @width, @height)
    @walk2 = Gosu::Image.new(filename).subimage(16, 16, @width, @height)
    @squished = Gosu::Image.new(filename).subimage(32, 16, @width, @height)
    # # This always points to the frame that is currently drawn.
    # # This is set in update, and used in draw.
    @cur_image = @standing
  end
end


# Support Procedures/Functions
def load_map_from_json(file_path)
  file = File.read(file_path)
  data = JSON.parse(file)
  Map.new(data)
end

def load_rounds_from_json(file_path)
  file = File.read(file_path)
  data = JSON.parse(file)
  data
end

# provide x and y to get tile from layer
# 2 dimensional grid is stored as single array
def tile_at(layer, x, y)
  # puts "x:#{x}, y:#{y}, index:#{y * layer.width + x}"
  return layer.data[y * layer.width + x]
end

def draw_character(character)
  # Flip vertically when facing to the left.
  if character.dir == :right
    factor = 1.0
  else
    factor = -1.0
  end
  character.cur_image.draw(character.x, character.y, 0, factor, 1.0)
end

def draw_player(player)
  draw_character player
end

def draw_enemy(enemy)
  draw_character enemy
end

def draw_enemies(enemies)
  for enemy in enemies
    draw_enemy enemy
  end
end

def try_to_jump(player)
  # if solid?(player.game_map, player.x, player.y + 1)
  player.vy = -12
  # end
end

def draw_map(map, x, y)
  map.layers.each do |layer|
    # puts "x:#{@x}, y:#{@y}"
    draw_layer(map, layer, x, y)
  end
end

def draw_layer(map, layer, offset_x, offset_y)
  if layer.type == 'tilelayer'
    draw_tiles(map, layer, offset_x, offset_y)
  elsif layer.type == 'objectgroup'
    # draw_objects(layer, offset_x, offset_y)
  end
end

def draw_objects(layer, offset_x, offset_y) end

def draw_tiles(map, layer, x, y)
  off_x = x / map.tilewidth
  off_y = y / map.tilewidth

  # tile_range_x = (off_x..screen_width_in_tiles + off_x)
  # tile_range_y = (off_y..screen_height_in_tiles + off_y)
  tile_range_x = (off_x..map.width + off_x)
  tile_range_y = (off_y..map.height + off_y)
  tile_range_y.each do |yy|
    tile_range_x.each do |xx|
      tile = tile_at(layer, xx, yy)
      if (tile != 0 && tile != nil)
        target_x = transpose_tile_x(xx, x)
        target_y = transpose_tile_y(yy, y)
        if (within_map_range(x + target_x, y + target_y))
          tileset = map.tilesets.fetch(1) # only have one tileset for now
          # tiles are stored in an array, hence index starts from 0. In Tiled, first tile is 1
          image = tileset.tiles[tile - 1]
          image.draw(target_x, target_y, 0)
        end
      end
    end
  end
end

def update_character(map, character, move_x)

  # We must not allow character to move out of screen to the left or to the right
  if move_x < 0 # will move to the left
    if character.x + move_x < character.width
      move_x = 0
    end
  end

  if move_x > 0 # will move to the right
    if character.x + character.width + move_x > map.width * map.tilewidth
      move_x = 0
    end
  end



  # Select image depending on action
  if (move_x == 0)
    character.cur_image = character.standing
  else
    character.cur_image = (Gosu.milliseconds / 175 % 2 == 0) ? character.walk1 : character.walk2
  end
  if (character.vy < 0)
    character.cur_image = character.jump
  end

  # Directional walking, horizontal movement
  if move_x > 0
    character.dir = :right
    move_x.times {
      if would_fit(map, character, SPEED, 0) then
        character.x += SPEED
      end
    }
  end
  if move_x < 0
    character.dir = :left
    (-move_x).times {
      if would_fit(map, character, -SPEED, 0) then
        character.x -= SPEED
      end
    }
  end

  # Acceleration/gravity
  # By adding 1 each frame, and (ideally) adding vy to y, the character's
  # jumping curve will be the parabole we want it to be.
  character.vy += 1

  # Vertical movement
  if character.vy > 0
    character.vy.times {
      if would_fit(map, character, 0, 1) then
        character.y += 1
      else
        character.vy = 0
      end
    }
  end
  if character.vy < 0
    (-character.vy).times {
      if would_fit(map, character, 0, -1) then
        character.y -= 1
      else
        character.vy = 0
      end
    }
  end
end

def would_fit(map, player, offset_x, offset_y)
  cur_pos_x1 = player.x
  cur_pos_y1 = player.y
  cur_pos_x2 = cur_pos_x1 + player.width
  cur_pos_y2 = cur_pos_y1 + player.height
  # puts "Current Position: x1:#{cur_pos_x1}, x2:#{cur_pos_x2}, y1:#{cur_pos_y1},y2:#{cur_pos_y2},"
  new_pos_x1 = cur_pos_x1 + offset_x
  new_pos_y1 = cur_pos_y1 + offset_y
  new_pos_x2 = new_pos_x1 + player.width
  new_pos_y2 = new_pos_y1 + player.height

  if(player.dir == :left)
    new_pos_x1 = new_pos_x1 - player.width
    new_pos_x2 = new_pos_x2 - player.width
  end

  # Find if overlaps if any other Group objects in map
  ground_layer = map.layers.select { |layer| layer.name == "Ground" }.first
  ground_layer.tiledobjects.each do |tiledobject|
    tile_pos_x1 = tiledobject.x
    tile_pos_y1 = tiledobject.y
    tile_pos_x2 = tile_pos_x1 + tiledobject.width
    tile_pos_y2 = tile_pos_y1 + tiledobject.height
    overlap = !(
    new_pos_x1 >= tile_pos_x2 ||
        new_pos_x2 <= tile_pos_x1 ||
        new_pos_y1 >= tile_pos_y2 ||
        new_pos_y2 <= tile_pos_y1
    )

    if (overlap)
      if tiledobject.y >= 224
        return false
      end
      # puts "Player Current Position: x1:#{cur_pos_x1}, x2:#{cur_pos_x2}, y1:#{cur_pos_y1},y2:#{cur_pos_y2},"
      # puts "Player New Position: x1:#{new_pos_x1}, x2:#{new_pos_x2}, y1:#{new_pos_y1},y2:#{new_pos_y2},"
      # puts "Tile Position: x1:#{tile_pos_x1}, x2:#{tile_pos_x2}, y1:#{tile_pos_y1},y2:#{tile_pos_y2},"
      # puts "Overlap detected"
      return false
    end
  end

  return true
end

def spawn_enemies(layer)
  enemies = []
  for enemytiledobject in layer.tiledobjects
    enemies << spawn_enemy(enemytiledobject)
  end
  enemies
end

def spawn_enemy(enemytiledobject)
  pp enemytiledobject
  enemy = Enemy.new(enemytiledobject)
  enemy
end

def change_character_direction(character)
  if(character.dir == :right)
    character.dir = :left
  elsif character.dir == :left
    character.dir = :right
  end
  character
end

class GameWindow < Gosu::Window
  def initialize
    super(WIDTH, HEIGHT, false)
    @rounds = load_rounds_from_json(ROUND_CONFIG)
    @current_round = @rounds["1"]
    load_map(@current_round)
  end

  def load_map(round)
    @map = load_map_from_json(@current_round)
    @x = @y = 0
    player_layer = @map.layers.select { |layer| layer.name == "Players" }.first
    player_tiled_object = player_layer.tiledobjects.select { |object| object.name == 'player1' }.first
    @player = Player.new(player_tiled_object.x, player_tiled_object.y)
    @camera_x = @camera_y = 0

    enemy_layer = @map.layers.select { |layer| layer.name == "Enemies"}.first
    @enemies = spawn_enemies(enemy_layer)
  end

  def update
    move_x = 0
    move_x -= VELOCITY if Gosu.button_down? Gosu::KB_LEFT
    move_x += VELOCITY if Gosu.button_down? Gosu::KB_RIGHT
    # Update the Player
    update_character(@map, @player, move_x)

    # Update all Enemies, enemy movement does not depend on key press
    for enemy in @enemies
      # Move enemy in the current direction
      offset_to_check = enemy.dir == :right ? SPEED : -SPEED
      if(!would_fit(@map,enemy,offset_to_check, 0)) # enemies only move left or right for now
        change_character_direction(enemy)
      end
      enemy_speed = enemy.dir == :left ? -ENEMY_GOOMBA_SPEED : ENEMY_GOOMBA_SPEED
      update_character(@map, enemy, enemy_speed)
    end

    # Scrolling follows player
    @camera_x = [[@player.x - WIDTH / 2, 0].max, @map.width * @map.tilewidth - WIDTH].min
    @camera_y = [[@player.y - HEIGHT / 2, 0].max, @map.height * @map.tileheight - HEIGHT].min

    # Player dies if goes out of height
    if @player.y > @map.tileheight * @map.height
      respawn_player
    end
  end

  def respawn_player
    # puts('Re spawning player')
    @player = Player.new(@camera_x, @camera_y)
  end

  def button_down(id)
    case id
    when Gosu::KB_UP
      if (@player.vy == 0)
        try_to_jump(@player)
      end
    when Gosu::KB_ESCAPE
      close
    else
      super
    end
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

  def within_map_range(x, y)
    (0..@map.width * @map.tilewidth - 1).include?(x) && (0..@map.height * @map.tileheight - 1).include?(y)
  end

  def draw
    # puts "Camera X is #{@camera_x}"
    # puts "Camera Y is #{@camera_y}"
    Gosu.translate(-@camera_x, -@camera_y) do
      draw_map(@map, @x, @y)
      draw_player @player
      draw_enemies @enemies
      # @ground_layer = @map.layers.select { |layer| layer.name == "Ground" }.first
      # @ground_layer.tiledobjects.each do |tiledobject|
      #   Gosu.draw_rect(tiledobject.x, tiledobject.y, tiledobject.width, tiledobject.height, Gosu::Color::RED)
      # end
    end
  end
end

GameWindow.new.show