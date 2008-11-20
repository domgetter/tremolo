begin
  # In case you use Gosu via RubyGems.
  require 'rubygems'
rescue LoadError
  # In case you don't.
end

require 'gosu' 
require 'common'
require 'texplay'

#manages environment (landscape)
class EnvironmentController

  
  def initialize(window)
    @window = window
    @envmap = []
    @tile_size_x = 420
    @tile_size_y = 322
    @tile_theme = {}       
    
    #mapping functions
    @map_to_screen = lambda { |x,y| [x * @tile_size_x, 124 + y * @tile_size_y] }
    @screen_to_map = lambda { |x,y| [(x / @tile_size_x).to_i, ((y - 124)/@tile_size_y).to_i] }
        
    setup_themes

  end
  
  def setup_themes  
    
    @tile_theme[:desert] = DesertTile
    @tile_theme[:lush] = LushTile
  end
  
  def load_env(thememap)    
    num_tiles = 0
    
    #break up the parameter into its theme and map number components
    theme,map = thememap.scan(/\d+|\D+/)
    
    #set path for this theme
    theme_path = "assets/#{theme}/"
    
    #map file
    mapfile = "#{theme_path}map#{map}"  
    
    #load the background
    @bg = Gosu::Image.new(@window, "#{theme_path}bg.png")
    
    lines = File.readlines(mapfile).map { |line| line.chop }
    
    #count the number of active tiles; tiles with numbers b/w 1 and 9
    num_tiles = lines.inject(0) { |memo,v| memo+v.count(('1'..'9').to_a.join) }
    @height = lines.size
    puts "loading environment..."
    puts "theme is: #{theme}; map is: map#{map}"
   
    @width = lines[0].size
   
    puts "#{num_tiles} tiles in the environment..."
    @tiles = Array.new(@height) do |y|
      Array.new(@width) do |x|
        t_type = lines[y][x, 1].to_i   
        if(t_type!=0):
          @tile_theme[theme.to_sym].new(@window,@tile_size_x,@tile_size_y,@map_to_screen,@screen_to_map,t_type,x,y,self)       
        end
        
      end
    end    
    puts "...done!"
  end
  
  def get_tile(x,y)
    #convert from screen to map coords
    map_x,map_y = *@screen_to_map.call(x,y)
    
    if(x<0 || y < 0): return; end 
    if(!@tiles[map_y]): return; end
     
    if(@tiles[map_y][map_x]):
      return @tiles[map_y][map_x]
      
    end    
  end
  
    
  
  def check_collision(actor, offset_x=0, offset_y=0)
  
    collision_point = OpenStruct.new
    collision_point.x = actor.x + offset_x
    collision_point.y = actor.y + offset_y 
    
    #convert from screen to map coords
    map_x,map_y=*@screen_to_map.call(collision_point.x,collision_point.y)
    
    if(collision_point.x < 0 || collision_point.y < 0): return; end 
    if(!@tiles[map_y]): return; end
     
    if(@tiles[map_y][map_x]):
      tile = @tiles[map_y][map_x]

      return tile.check_collision(collision_point.x,collision_point.y)
    end    
  end
  
  def draw(ox,oy)
  
    #draw the background
    @bg.draw(0, 0, Common::ZOrder::Background)
    
    #draw the tiles
    @height.times do |y|
      @width.times do |x|
        if(tile=@tiles[y][x]): tile.draw(x,y,ox,oy);end 
      end
    end
  end

end

#abstract base class for tiles
class Tile
  #class counter
  @@count_instance = 0  
  
  #utility class
  Clr=Struct.new(:r,:g,:b,:a)
  
  attr_reader :x,:y
  
  #meaningless but necessary for consistent interface
  attr_accessor :freeze
  
  def initialize(window,size_x,size_y,map_to_screen,screen_to_map,t_type,x,y, env)
    @@count_instance+=1
    @window = window
    @env = env
    @size_x = size_x
    @size_y = size_y
    @map_to_screen = map_to_screen
    @screen_to_map = screen_to_map
    @t_type = t_type
    @radius_dmg = 30
    
    #probably meaningless for this class
    @freeze = false 
    
    @x,@y = @map_to_screen.call(x,y)
    
    puts "loading tile #{@@count_instance}.."
    
    #define in subclass
    set_theme
    
    setup_gfx
    setup_sound    
  end
  
  def set_theme
    @theme = ""
  end
  
  def setup_gfx
    #get filename of tile image
    file = "assets/#{@theme}/#{@theme}#{@t_type}.png"
    
    @image = Gosu::Image.new(@window,file)  
    @width = @image.width
    @height = @image.height
  end
  
  
  #standard, override in subclasses
  def setup_sound
   @effects = EffectsSystem.new(@window)
   @effects.add_effect(:thud, "assets/sand2.ogg")
  end
  
  #NOTE: equation is different from Actor's as Tiles are drawn from TOP LEFT, not center
  def visible?(sx,sy)
    (sx + @width > 0 && sx < Common::SCREEN_X && sy + @height > 0 && 
     sy < Common::SCREEN_Y) 
  end
  
  def draw(x,y,ox,oy)
    x,y = @map_to_screen.call(x,y)
    
    #screen coords
    sx = x-ox
    sy = y-oy
    
    return if !visible?(sx,sy)
           
    @image.draw(sx, sy, Common::ZOrder::Tile)
    
   #if @x == 420 then TexPlay.leftshift @image, 2, :loop end   #CHANGED!
  end
  
  def check_collision(cp_x, cp_y)
   
    #my_x,my_y=@map_to_screen.call(my_x,my_y)
     
    x = (cp_x - @x).to_i
    y = (cp_y - @y).to_i 
       
    if(TexPlay.get_pixel(@image, x, y)[3] !=0) then return self;  end
    

  end
  
  #override in base-class
  def do_collision(actor,offset_x=0,offset_y=0)
    puts "A #{self.class} collided with a #{actor.class}"
    
    s = OpenStruct.new
    
    s.x = actor.x + offset_x
    s.y = actor.y + offset_y
    
    case actor
    when Projectile
        @effects.play_effect(:thud)   
    else
            
    end

    #convert from screen coords to local coords of tile, with origin at top left
    vx = s.x - @x
    vy = s.y - @y
      
    #splash damage for other tiles
    tile = @env.get_tile(s.x + @radius_dmg, s.y)
    if(tile && tile != self) then tile.do_damage(s.x - tile.x, s.y - tile.y); end
    
    tile = @env.get_tile(s.x - @radius_dmg, s.y)
    if(tile && tile != self) then tile.do_damage(s.x - tile.x, s.y - tile.y); end
    
    tile = @env.get_tile(s.x, s.y  + @radius_dmg)
    if(tile && tile != self) then tile.do_damage(s.x - tile.x, s.y - tile.y); end
    
    tile = @env.get_tile(s.x, s.y  - @radius_dmg)
    if(tile && tile != self) then tile.do_damage(s.x - tile.x, s.y - tile.y); end
    
    tile = @env.get_tile(s.x - @radius_dmg, s.y  - @radius_dmg)
    if(tile && tile != self) then tile.do_damage(s.x - tile.x, s.y - tile.y); end
    
    tile = @env.get_tile(s.x + @radius_dmg, s.y  - @radius_dmg)
    if(tile && tile != self) then tile.do_damage(s.x - tile.x, s.y - tile.y); end
    
    tile = @env.get_tile(s.x - @radius_dmg, s.y  + @radius_dmg)
    if(tile && tile != self) then tile.do_damage(s.x - tile.x, s.y - tile.y); end
    
    tile = @env.get_tile(s.x + @radius_dmg, s.y  + @radius_dmg)
    if(tile && tile != self) then tile.do_damage(s.x - tile.x, s.y - tile.y); end
            
    
    #damage for this tile
    do_damage(vx, vy)    

  end
  
  def do_damage(x, y)
     r = @radius_dmg
     TexPlay.draw(@image) {
        color :alpha
        circle x, y,r
    }
    
   
  end
  
  def info
    "Object information:\nType: #{self.class}; Sub-type: #{@t_type}"
  end
  
  #round x to nearest multiple of y
  def round_to_mult(x,y) 
    (x/y.to_f).round*y
  end
  
  private :round_to_mult, :setup_gfx, :setup_sound, :visible? 
  
end

#desert tile class
class DesertTile < Tile
  def set_theme
    @theme = "desert"
  end
end

#desert tile class
class LushTile < Tile
  def set_theme
    @theme = "lush"
  end
end




        

    

      