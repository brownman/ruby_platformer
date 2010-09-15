#!/usr/bin/ruby

require 'rubygems'
require 'pretty-fsm'
require 'chingu'
include Gosu
include Chingu

class GameWindow < Chingu::Window
    def initialize
        super(1024,768)
        self.input = {:esc => :exit}
        switch_game_state(Engine_test.new)
    end    
end

class Platform < GameObject
    has_traits :collision_detection
    attr_accessor :color, :box
    
    def initialize(options = {})
        super
        @box = Rect.new([@x, @y, options[:width], options[:height]])
        @color = options[:color] or Color.new(255,255,0,0)
        @color2 = Color.new(255,0,128,255)
    end
    
    def bounding_box
        @box
    end
    
    def draw
        $window.fill_rect(@box, @color)
        $window.fill_rect(@box.left_side, @color2)
        $window.fill_rect(@box.right_side, @color2)
        $window.fill_rect(@box.top_side, @color2)
        $window.fill_rect(@box.bottom_side, @color2)
    end
end

# player class
class Player < GameObject
   traits :velocity, :collision_detection

   attr_accessor :pressed_left, :pressed_right, :pressed_jump
   include PrettyFSM::Abbreviate
    
   def initialize(options = {})
      super
      @color = options[:color] or Color.new(255,0,0,255)
      @box = Rect.new([@x, @y, 20, 20])
      @accel = 0.2
      @skid = 0.6
      @decel = 0.18
      @pressed_jump = false
      @pressed_left = false
      @pressed_right = false
      self.acceleration_y = 0.3
      self.max_velocity_y = 10
      self.max_velocity_x = 12
   end
    
   def bounding_box
      @box
   end

   def update
      # moving left
      if @pressed_left
         if velocity_x > 0
            self.acceleration_x = -@skid
         else
            self.acceleration_x = -@accel
         end
      end
      
      if @pressed_right
         if velocity_x < 0
            self.acceleration_x = @skid
         else
            self.acceleration_x = @accel
         end
      end

      # slow to stop on ground
      if (!@pressed_left and !@pressed_right) and self.velocity_x != 0
         self.acceleration_x = 0
        
         # stop if velocity is low enough
         if (self.velocity_x <= 0.2 and self.velocity_x > 0) or
            (self.velocity_x >= -0.2 and self.velocity_x < 0)
            self.velocity_x = 0
         elsif self.velocity_x < 0 # moving left
            self.velocity_x += @decel
         else                   # moving right
            self.velocity_x -= @decel
         end
      end

      if self.velocity_x >= self.max_velocity_x
         self.velocity_x = self.max_velocity_x
      end

      # keep box from leaving sides of screen
      if @x < 0
         @x = 0
         self.velocity_x = 0
         self.acceleration_x = 0
      end

      if (@x + @box.width) > $window.width
         @x = $window.width - @box.width
         self.velocity_x = 0
         self.acceleration_x = 0
      end
      
      # keep box from leaving top/bottom of screen
      if @y < 0
         @y = 0
         self.velocity_y = 0
      end

      if (@y + @box.height) > $window.height
         @y = $window.height - @box.height
      end
      
      # update box position
      @box.x = @x
      @box.y = @y
   end

   def draw
      $window.fill_rect(@box, @color)
   end
   
   # Collision response
   def resolve_collisions
      self.each_collision(Platform) do | me, platform |
         me.resolve_platforms(platform)
      end
   end

   def resolve_platforms(platform)
      # if player collides with top of platform
      if ((@y + @box.height) >= platform.x) and (@y < platform.y) and (((@x + @box.width) >= platform.x) or (@x <= (platform.x + platform.box.width)))
         @y = platform.box.y - @box.height
         self.velocity_y = 0

      # if player collides with bottom of platform
      elsif (@y <= (platform.x + platform.box.height)) and ((@y + @box.height) > (platform.y + platform.box.height)) and (((@x + @box.width) >= platform.x) or (@x <= (platform.x + platform.box.width)))
         @y = platform.box.y + platform.box.height + 1
         self.velocity_y = 0

      # if player colides with left side of platform
      elsif ((@x + @box.width) >= platform.x) and (@x < platform.x) and (((@y + @box.height) >= platform.y) or (@y <= (platform.y + platform.box.height)))
         @x = platform.box.x - @box.width
         self.velocity_x = 0
         self.acceleration_x = 0

      # if player collides with right side of platform
      elsif ((@x <= (platform.x + platform.box.width)) and ((@x + @box.width) > (platform.x + platform.box.width)) and (((@y + @box.height) >= platform.y) or (@y <= (platform.y + platform.box.height))))
         @x = platform.box.x + platform.box.width
         self.velocity_x = 0
         self.acceleration_x = 0
      end
   end
end

# main game state
class Engine_test < GameState
    def initialize()
        super
        $window.caption = "Platform Engine Test initial testing version"
        @platform = Platform.create( :x => 0, :y => 718, :width => 1024, :height => 50, :color => Color.new(255,255,255,0))
        @platform2 = Platform.create( :x => 512, :y => 668, :width => 50, :height => 50, :color => Color.new(255,255,255,0))
        @platform3 = Platform.create( :x => 450, :y => 600, :width => 300, :height => 50, :color => Color.new(255,0,255,0)) 
        @player = Player.create( :x => 100, :y => 200, :color => Color.new(255,0,255,0))
        @player.input = { :holding_left   => Proc.new { @player.pressed_left = true; @player.pressed_right = false },
                          :holding_right  => Proc.new { @player.pressed_right = true; @player.pressed_left = false },
                          :released_left  => Proc.new { @player.pressed_left = false },
                          :released_right => Proc.new { @player.pressed_right = false },
                          :holding_space  => Proc.new { @player.pressed_jump = true },
                          :released_space => Proc.new { @player.pressed_jump = false },
                        }
    end
end

GameWindow.new.show
