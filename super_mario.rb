require 'gosu'
require 'pp'
require 'json'

WIDTH = 800
HEIGHT = 256
ASSETS_DIR = 'assets'
VELOCITY = 2
SPEED = 1.5
ENEMY_GOOMBA_VELOCITY = 1
ENEMY_GOOMBA_SPEED = 1.0
ROUND_CONFIG = 'assets/rounds.json'
# enemy waits before changing direction
ENEMY_GOOMBA_WAIT_TIME = 1000

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
  attr_accessor :x, :y, :dir, :vy, :standing, :walk1, :walk2, :jump, :cur_image, :width, :height, :status, :killed, :wait_time

  def initialize(x, y)
    @x = x
    @y = y
    @width = 16
    @height = 15
    @vy = 0
    @dir = :right
    filename = "assets/NES - Super Mario Bros - Mario & Luigi.png"
    @standing = Gosu::Image.new(filename).subimage(80, 35, @width, @height)
    @walk1 = Gosu::Image.new(filename).subimage(97, 35, @width, @height)
    @walk2 = Gosu::Image.new(filename).subimage(114, 35, @width, @height)
    @jump = Gosu::Image.new(filename).subimage(148, 35, @width, @height)
    @killed = Gosu::Image.new(filename).subimage(182, 35, @width, @height)
    # # This always points to the frame that is currently drawn.
    # # This is set in update, and used in draw.
    @cur_image = @standing
    @status = :active
    @wait_time = nil
  end
end

class Enemy
  attr_accessor :x, :y, :dir, :vy, :standing, :walk1, :walk2, :squished, :cur_image, :width, :height, :waiting, :wait_time, :status, :killed

  def initialize(tiledobject)
    @x = tiledobject.x
    @y = tiledobject.y
    @dir = tiledobject.properties.select { |property| property.name == "dir" }.first.value
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
    @waiting = false
    @wait_time = nil
    @status = false
    @killed = nil
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
  if character.status == :killed && character.killed != nil
    character.cur_image = character.killed
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

def draw_layer(map, layer, camera_x, camera_y)
  if layer.type == 'tilelayer'
    draw_tiles(map, layer, camera_x, camera_y)
  elsif layer.type == 'objectgroup'
    # draw_objects(layer, camera_x, camera_y)
  end
end

def draw_objects(layer, camera_x, camera_y) end

def draw_tiles(map, layer, camera_x, camera_y)
  tile_range_x = (0..map.width)
  tile_range_y = (0..map.height)

  # puts ("Tile_range_x Length is #{tile_range_x.inspect}")
  # puts ("Tile_range_y Length is #{tile_range_y.inspect}")
  tile_range_y.each do |yy|
    tile_range_x.each do |xx|
      tile = tile_at(layer, xx, yy)
      if (tile != 0 && tile != nil)
        target_x = xx * map.tilewidth
        target_y = yy * map.tileheight
        tileset = map.tilesets.fetch(1)
        # tiles are stored in an array, hence index starts from 0. In Tiled, first tile is 1
        tile_index = tile - 1
        image = tileset.tiles[tile_index]
        image.draw(target_x, target_y, 0)
      end
    end
  end
end

def character_will_go_out_of_screen(map, character, move_x)
  # We must not allow character to move out of screen to the left or to the right
  if move_x < 0 # will move to the left
    if character.x + move_x < character.width
      return true
    end
  end

  if move_x > 0 # will move to the right
    if character.x + character.width + move_x > map.width * map.tilewidth
      return true
    end
  end

  return false
end

def update_character(map, character, move_x, speed)

  # If we know the character will go out of the boundaries of the screen, we stop movement
  if (character_will_go_out_of_screen(map, character, move_x))
    move_x = 0
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
      if would_fit(map, character, speed, 0) then
        character.x += speed
      end
    }
  end
  if move_x < 0
    character.dir = :left
    (-move_x).times {
      if would_fit(map, character, -speed, 0) then
        character.x -= speed
      end
    }
  end

  # Acceleration/gravity
  # By adding 1 each frame, and (ideally) adding vy to y, the character's
  # jumping curve will be the parabole we want it to be.
  character.vy += 1

  down_speed = character.status == :killed ? 0.05 : 0.5 # we kill the player slowly
  # Vertical movement
  if character.vy > 0
    character.vy.times {
      if (character.status == :killed)
        character.y += down_speed
      elsif would_fit(map, character, 0, 1)
        character.y += down_speed
      else
        character.vy = 0
      end
    }
  end
  if character.vy < 0
    (-character.vy).times {
      if would_fit(map, character, 0, -1)
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

  if (player.dir == :left)
    new_pos_x1 = new_pos_x1 - player.width
    new_pos_x2 = new_pos_x2 - player.width
  end

  # Find if overlaps if any other Group objects in map
  ground_layer = map.layers.select { |layer| layer.name == "Ground" }.first
  collision = detect_collision_with_layer_objects(ground_layer, new_pos_x1, new_pos_x2, new_pos_y1, new_pos_y2)

  if (collision)
    return false # won't fit
  end

  return true # no collision
end

def detect_collision_with_layer_objects(layer, new_pos_x1, new_pos_x2, new_pos_y1, new_pos_y2)
  layer.tiledobjects.each do |tiledobject|
    tile_pos_x1 = tiledobject.x
    tile_pos_y1 = tiledobject.y
    tile_pos_x2 = tile_pos_x1 + tiledobject.width
    tile_pos_y2 = tile_pos_y1 + tiledobject.height
    overlap = rectangles_overlap(new_pos_x1, new_pos_x2, new_pos_y1, new_pos_y2, tile_pos_x1, tile_pos_x2, tile_pos_y1, tile_pos_y2)

    if (overlap)
      return true
    end
  end

  return false
end

# Detect if two rectangles overlap
# https://stackoverflow.com/questions/306316/determine-if-two-rectangles-overlap-each-other
# In Gosu, (0,0) is top left, this formula has been adjusted to account for that.
def rectangles_overlap(r1x1, r1x2, r1y1, r1y2, r2x1, r2x2, r2y1, r2y2)
  return !(
  r1x1 >= r2x2 ||
      r1x2 <= r2x1 ||
      r1y1 >= r2y2 ||
      r1y2 <= r2y1
  )
end

def spawn_enemies(layer)
  enemies = []
  for enemytiledobject in layer.tiledobjects
    enemies << spawn_enemy(enemytiledobject)
  end
  enemies
end

def spawn_enemy(enemytiledobject)
  enemy = Enemy.new(enemytiledobject)
  enemy
end

def change_character_direction(character)

  if (character.dir == :right)
    character.dir = :left
  elsif character.dir == :left
    character.dir = :right
  end
  character
end

def update_enemies(map, enemies)
  for enemy in enemies
    # Move enemy in the current direction
    offset_to_check = enemy.dir == :right ? SPEED : -SPEED
    wont_fit = !would_fit(map, enemy, offset_to_check, 0) # check collisions with ground objects
    enemy_speed = enemy.dir == :left ? -ENEMY_GOOMBA_VELOCITY : ENEMY_GOOMBA_VELOCITY
    # will_go_out_left = enemy
    if (wont_fit or character_will_go_out_of_screen(map, enemy, enemy_speed)) # enemies only move left or right for now
      if !enemy.waiting
        enemy.waiting = true
        enemy.wait_time = Gosu.milliseconds + ENEMY_GOOMBA_WAIT_TIME
      end
      if enemy.waiting && enemy.wait_time < Gosu.milliseconds
        change_character_direction(enemy)
        enemy.waiting = false
        enemy.wait_time = nil
      end

    end
    enemy_speed = enemy.dir == :left ? -ENEMY_GOOMBA_VELOCITY : ENEMY_GOOMBA_VELOCITY # we find speed again, direction might have changed
    update_character(map, enemy, enemy_speed, ENEMY_GOOMBA_SPEED)
  end
end

def detect_player_enemy_collision(player, enemies)
  for enemy in enemies
    if (rectangles_overlap(player.x, player.x + player.width, player.y, player.y + player.height, enemy.x, enemy.x + enemy.width, enemy.y, enemy.y + enemy.height))
      return true
    end
  end
  return false
end

def detect_player_gateway_collision(player, gatewaytiledobjects)
  for gateway in gatewaytiledobjects
    if (rectangles_overlap(player.x, player.x + player.width, player.y, player.y + player.height, gateway.x, gateway.x + gateway.width, gateway.y, gateway.y + gateway.height))
      return gateway.properties.select { |property| property.name == 'next_level' }.first.value
    end
  end
  return false
end

class GameWindow < Gosu::Window
  def initialize
    super(WIDTH, HEIGHT, false)
    @rounds = load_rounds_from_json(ROUND_CONFIG)
    @current_round = @rounds["1"]
    load_map(@current_round)
  end

  def load_map(round)
    @map = load_map_from_json(round)
    player_layer = @map.layers.select { |layer| layer.name == "Players" }.first
    player_tiled_object = player_layer.tiledobjects.select { |object| object.name == 'player1' }.first
    @player = Player.new(player_tiled_object.x, player_tiled_object.y)
    @camera_x = @camera_y = 0

    enemy_layer = @map.layers.select { |layer| layer.name == "Enemies" }.first
    @enemies = spawn_enemies(enemy_layer)
    @record = self.record(@map.tilewidth * @map.width, @map.tileheight * @map.height) do
      draw_map(@map,0,0)
    end
  end

  def update
    move_x = 0
    move_x -= VELOCITY if Gosu.button_down? Gosu::KB_LEFT
    move_x += VELOCITY if Gosu.button_down? Gosu::KB_RIGHT
    # Update the Player
    update_character(@map, @player, move_x, SPEED)

    # Update all Enemies, enemy movement does not depend on key press
    update_enemies(@map, @enemies)

    collision = detect_player_enemy_collision(@player, @enemies)
    if (collision)
      puts 'Collision with enemy'
      @player.status = :killed
      @player.vy = -10
    end

    # Check player reached gateway, load next level from gateway
    @gateway_layer = @map.layers.select { |layer| layer.name == "Gateways" }.first
    next_level = detect_player_gateway_collision(@player, @gateway_layer.tiledobjects)
    if next_level != false && @rounds[next_level]
      pp next_level
      load_map @rounds["#{next_level}"]
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

  def draw
    # puts "Camera X is #{@camera_x}"
    # puts "Camera Y is #{@camera_y}"
    Gosu.translate(-@camera_x, -@camera_y) do
        @record.draw(0, 0, 0)
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