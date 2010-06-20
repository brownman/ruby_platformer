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
    attr_accessor :color, :radius, :box
    
    def initialize(options = {})
        super
        @box = Rect.new([@x, @y, options[:width], options[:height]])
        @color = options[:color] or Color.new(255,255,0,0)
    end
    
    def bounding_box
        @box
    end
    
    def draw
        $window.fill_rect(@box, @color)
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
      @decel = 0.4
      @pressed_jump = false
      @pressed_left = false
      @pressed_right = false
      self.acceleration_y = 0.3
      self.max_velocity_y = 10
      self.max_velocity_x = 12
      @fsm = PrettyFSM::FSM.new(self, self.initial_state) do
         transition :from => :idle, :to => :moving, :if => :can_move?
         transition :from => :idle, :to => :jumping, :if => :can_jump?
         transition :from => :idle, :to => :falling, :if => :can_fall?
            
         transition :from => :moving, :to => :idle, :if => :stopped?
         transition :from => :moving, :to => :jumping, :if => :can_jump?
         transition :from => :moving, :to => :falling, :if => :can_fall?
            
         #transition :from => :jumping, :to => :moving, :if => Proc.new { !self.can_fall? and self.velocity_x != 0 }
         transition :from => :jumping, :to => :falling, :if => :can_fall?
         #transition :from => :jumping, :to => :idle, :if => :collide_platform?
         #transition :from => :jumping, :to => :moving, :if => :moving_and_collide_platform?
            
         transition :from => :falling, :to => :moving, :if => :moving_and_collide_platform?
         transition :from => :falling, :to => :idle, :if => :collide_platform?
      end
   end
    
   def bounding_box
      @box
   end
    
   def initial_state
      puts "initial_state"
      if self.first_collision(Platform)
         return "idle".to_sym
      else
         return "falling".to_sym
      end
   end
    
   # idle state functions
   def start_idle
      puts "start_idle"
      
   end
    
   def while_idle
      puts "idling"
      self.resolve_collisions
   end

   def stopped?
      puts "stopped?"
      return self.velocity_x == 0
   end
    
   # walking/running state functions
   def start_moving
      puts "start_moving"
   end
    
   def while_moving
      puts "moving"
      # if user is pressing a direction button
      if @pressed_right && self.velocity_x < 0
         self.acceleration_x = 0
         self.velocity_x += @skid
      elsif @pressed_left && self.velocity_x > 0
         self.acceleration_x = 0
         self.velocity_x -= @skid
      elsif @pressed_right
         #self.velocity_x += @accel unless self.velocity_x >= @max_velocity
         self.acceleration_x = @accel
      elsif @pressed_left
         #self.velocity_x -= @accel unless self.velocity_x <= -@max_velocity
         self.acceleration_x = -@accel
      end
      
      #if user is not pressing a direction button
      if (not @pressed_right) and (not @pressed_left)
         # bring player to a stop if velocity is less than a whole number and
         # close to zero
         if @fsm.state == :jumping or @fsm.state == :falling
            self.acceleration_x = 0
         else
         if (self.velocity_x > 0 and self.velocity_x < 1) or (self.velocity_x < 0 and self.velocity_x > -1)
            self.velocity_x = 0
            self.acceleration_x = 0
         end
         
         if self.velocity_x > 0
            #self.velocity_x -= @decel unless (self.velocity_x - @skid) < 0
            self.acceleration_x = -@decel
         elsif self.velocity_x < 0
            #self.velocity_x += @decel unless (self.velocity_x + @skid) > 0 
            self.acceleration_x = @decel
         end
         end
      end
      self.resolve_collisions
   end
    
   def can_move?
      puts "can_move?"
      @pressed_left or @pressed_right
   end
    
   # jumping functions
   def start_jumping
      puts "start_jumping"
      @y -= 1
      self.velocity_y = -10
   end
    
   def while_jumping
      puts "jumping"
      if @pressed_jump == false
         self.velocity_y += 1
      end
      self.while_moving
   end
   
   def can_jump?
      puts "can_jump?"
      return true if @pressed_jump and ((@fsm.state != :jumping) and (@fsm.state != :falling))
      return false
   end
    
   # falling functions
   def start_falling
      puts "start_falling"
   end
    
   def while_falling
      puts "falling"
      self.while_moving
   end

   def end_falling
      
   end

   def can_fall?
      puts "can_fall?"
      self.each_collision(Platform) do
         if @fsm.state == :jumping
            return true
         end
         return false
      end
      return false if self.velocity_y < 0
      return false if (@fsm.state == :jumping) and velocity == 0
      return true
   end
    
   def moving_and_collide_platform?
      puts "moving_and_collide_platform?"
      if self.velocity_x == 0
         return false
      end
      return self.collide_platform?
   end

   def collide_platform?
      puts "collide_platform?"
      self.each_collision(Platform) do
         return true
      end
      return false
   end
   
   def update
      #self.resolve_collisions
      @fsm.advance
      
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
         me.resolve_platform(platform)
      end
   end

   def resolve_platform(platform)
      @y = platform.box.y - @box.height
   end
end

# main game state
class Engine_test < GameState
    def initialize()
        super
        $window.caption = "Platform Engine Test initial testing version"
        @platform = Platform.create( :x => 0, :y => 718, :width => 1024, :height => 50, :color => Color.new(255,255,255,0))
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
