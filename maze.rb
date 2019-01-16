#!/usr/bin/env ruby

require "curses"

Curses.init_screen
Curses.start_color

SCREEN_WIDTH = 120
SCREEN_HEIGHT = 40

player_x = 22.0
player_y = 1.0
player_a = 0.0

map_height = 23
map_width = 73

fov = 3.14159 / 4
f_depth = 10
speed = 5.0

show_map = false

map_string = <<-EOS
#####################################################################   #
#   #               #               #           #                   #   #
#   #   #########   #   #####   #########   #####   #####   #####   #   #
#               #       #   #           #           #   #   #       #   #
#########   #   #########   #########   #####   #   #   #   #########   #
#       #   #               #           #   #   #   #   #           #   #
#   #   #############   #   #   #########   #####   #   #########   #   #
#   #               #   #   #       #           #           #       #   #
#   #############   #####   #####   #   #####   #########   #   #####   #
#           #       #   #       #   #       #           #   #           #
#   #####   #####   #   #####   #   #########   #   #   #   #############
#       #       #   #   #       #       #       #   #   #       #       #
#############   #   #   #   #########   #   #####   #   #####   #####   #
#           #   #           #       #   #       #   #       #           #
#   #####   #   #########   #####   #   #####   #####   #############   #
#   #       #           #           #       #   #   #               #   #
#   #   #########   #   #####   #########   #   #   #############   #   #
#   #           #   #   #   #   #           #               #   #       #
#   #########   #   #   #   #####   #########   #########   #   #########
#   #       #   #   #           #           #   #       #               #
#   #   #####   #####   #####   #########   #####   #   #########   #   #
#   #                   #           #               #               #   #
#   #####################################################################
EOS


map = map_string.gsub("\n","").chars

begin

  win = Curses::Window.new(SCREEN_HEIGHT, SCREEN_WIDTH, 0, 0)
  win.keypad = true
  win.timeout = 5
  win.nodelay = true

  ts_1 = Time.now.to_f
  ts_2 = Time.now.to_f
  elaspsed_time = 0.0


  loop do
    # Timing

    ts_2 = Time.now.to_f
    elaspsed_time = ts_2 - ts_1
    ts_1 = ts_2

    sleep(0.05)

    # Input
    key = win.getch

    if key == 'm'
      show_map = !show_map
    end

    if key == 'a'
      player_a -= (speed * 0.75) * elaspsed_time
    end
    if key == 'd'
      player_a += (speed * 0.75) * elaspsed_time
    end
    if key == 'w'
      player_x += Math.sin(player_a) * speed * elaspsed_time
		  player_y += Math.cos(player_a) * speed * elaspsed_time
		  if map[player_x.to_i * map_width + player_y.to_i] == '#'
        player_x -= Math.sin(player_a) * speed * elaspsed_time
        player_y -= Math.cos(player_a) * speed * elaspsed_time
      end
    end
    if key == 's'
      player_x -= Math.sin(player_a) * speed * elaspsed_time
		  player_y -= Math.cos(player_a) * speed * elaspsed_time
		  if map[player_x.to_i * map_width + player_y.to_i] == '#'
        player_x += Math.sin(player_a) * speed * elaspsed_time
        player_y += Math.cos(player_a) * speed * elaspsed_time
      end
    end

    # Logic
    screen = Array.new(SCREEN_WIDTH * SCREEN_HEIGHT - 1) { ' ' }


    (0...SCREEN_WIDTH).each do |x|
      ray_angle = (player_a - fov / 2.0) + (x.to_f / SCREEN_WIDTH.to_f) * fov
      step_size = 0.1
      distance_to_wall = 0.0
      hit_wall = false
      boundary = false

      eye_x = Math.sin(ray_angle)
      eye_y = Math.cos(ray_angle)

      while (!hit_wall && distance_to_wall < f_depth) do
        distance_to_wall += step_size
        test_x = (player_x + eye_x * distance_to_wall).to_i
        test_y = (player_y + eye_y * distance_to_wall).to_i
        if (test_x < 0 || test_x >= map_height || test_y < 0 || test_y >= map_width)
          hit_wall = true
          distance_to_wall = f_depth
        else
          if map[test_x * map_width + test_y] == '#'
            hit_wall = true

            pairs = []

            (0...2).each do |tx|
              (0...2).each do |ty|
                vy = test_y.to_f + ty - player_y
								vx = test_x.to_f + tx - player_x
								d = Math.sqrt(vx*vx + vy*vy)
								dot = d > 0 ? (eye_x * vx / d) + (eye_y * vy / d) : 0.0
								pairs.push([d, dot])
              end
            end

            pairs = pairs.sort {|a,b| a.first  <=> b.first || 0}


            bound = 0.01
            if Math.acos(pairs[0].last) < bound
              boundary = true
            end
            if Math.acos(pairs[1].last) < bound
              boundary = true
            end
            if Math.acos(pairs[2].last) < bound
              boundary = true
            end

          end
        end
      end

      ceiling = (SCREEN_HEIGHT  / 2.0) - SCREEN_HEIGHT / distance_to_wall.to_f
      floor = SCREEN_HEIGHT - ceiling

      shade = ' ';
			if (distance_to_wall <= f_depth / 4.0)
        shade = "█"
			elsif (distance_to_wall < f_depth / 3.0)
        shade = "▓"
			elsif (distance_to_wall < f_depth / 2.0)
        shade = "▒"
			elsif (distance_to_wall < f_depth)
        shade = "░"
			else
        shade = ' '
      end
      if boundary
        shade = '|'
      end

      (0...SCREEN_HEIGHT).each do |y|

        if y <= ceiling
          screen[y*SCREEN_WIDTH+x] = ' '
        elsif y > ceiling && y <= floor
          screen[y*SCREEN_WIDTH+x] = shade
        else
          b = 1.0 - ((y.to_f - SCREEN_HEIGHT / 2.0) / (SCREEN_HEIGHT.to_f / 2.0))
          if b < 0.25
            shade = '#'
					elsif b < 0.5
            shade = 'x'
					elsif b < 0.75
            shade = '.'
					elsif b < 0.9
            shade = '-'
					else
            shade = ' '
          end
          screen[y*SCREEN_WIDTH+x] = shade
        end

      end

    end

    player_degrees = (player_a % 6.28) * 57.295779513 + 90

    status_string = ("X=%3.2f, Y=%3.2f, A=%3.2f FPS=%3.2f" % [player_x, player_y, player_a, 1.0/elaspsed_time]).chars
    status_start = 0
    status_end = status_start + status_string.size
    screen[status_start...status_end] = status_string

    if show_map
      (0...map_height).each do |my|
        (0...map_width).each do |mx|
          screen[(my + 1) * SCREEN_WIDTH + mx] = map[my * map_width + mx]
        end
      end
      if player_degrees > 45 && player_degrees <= 135
        player_char = ">"
      end
      if player_degrees > 135 && player_degrees <= 225
        player_char = "V"
      end
      if player_degrees > 225 && player_degrees <= 315
        player_char = "<"
      end
      if player_degrees > 315 || player_degrees <= 45
        player_char = "^"
      end
      screen[(player_x.to_i + 1) * SCREEN_WIDTH + player_y.to_i] = player_char
    end


    # Render
    win.clear
    win.addstr(screen.join)
    win.refresh
  end

ensure
  Curses.close_screen
end
