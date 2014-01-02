# tco - terminal colouring application and library
# Copyright (C) 2013 Radek Pazdera
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

module Tco
  class Colour
    attr_reader :rgb, :lab

    def initialize(rgb, lab=nil)
      @rgb = rgb
      @lab = lab ? lab : rgb_to_lab(rgb)
    end

    def -(other)
      delta_e_2000 @lab, other.lab
    end

    private

    # source: http://www.easyrgb.com/index.php?X=MATH&H=02#text2
    def rgb_to_xyz(colour)
      r, g, b = colour.map do |v|
          v /= 255.0
          if v > 0.04045
              v = ((v + 0.055 ) / 1.055)**2.4
          else
              v = v / 12.92
          end
          v *= 100
      end

      #Observer = 2°, Illuminant = D65
      x = r * 0.4124 + g * 0.3576 + b * 0.1805
      y = r * 0.2126 + g * 0.7152 + b * 0.0722
      z = r * 0.0193 + g * 0.1192 + b * 0.9505

      return [x, y, z]
    end

    def xyz_to_lab(colour)
      f = lambda { |t|
        return t**(1.0/3) if t > (6.0 / 29)**3
        return (1.0 / 3) * ((29.0 / 6)**2) * t + (4.0 / 29)
      }

      x, y, z = colour
      xn, yn, zn = rgb_to_xyz([255, 255, 255])
      l = 116 * f.call(y/yn) - 16
      a = 500 * (f.call(x/xn) - f.call(y/yn))
      b = 200 * (f.call(y/yn) - f.call(z/zn))

      return [l, a, b]
    end

    def rgb_to_lab(rgb_val)
      xyz_to_lab rgb_to_xyz rgb_val
    end

    def rad_to_deg(v)
      (v * 180) / Math::PI
    end

    def deg_to_rad(v)
      (v * Math::PI) / 180
    end

    def CieLab2Hue(a, b)
      bias = 0
      return 0 if (a >= 0 && b == 0)
      return 180 if (a <  0 && b == 0)
      return 90 if (a == 0 && b > 0)
      return 270 if (a == 0 && b < 0)

      bias = case
      when a > 0 && b > 0 then 0
      when a < 0 then 180
      when a > 0 && b < 0 then 360
      end

      rad_to_deg(Math.atan(b / a)) + bias
    end

    def delta_e_2000(lab1, lab2)
      l1, a1, b1 = lab1
      l2, a2, b2 = lab2
      kl, kc, kh = [1, 1, 1]

      xC1 = Math.sqrt(a1**2 + b1**2)
      xC2 = Math.sqrt(a2**2 + b2**2)
      xCX = (xC1 + xC2) / 2
      xGX = 0.5 * (1 - Math.sqrt(xCX**7 / (xCX**7 + 25**7)))
      xNN = (1 + xGX) * a1
      xC1 = Math.sqrt(xNN**2 + b1**2)
      xH1 = CieLab2Hue(xNN, b1)
      xNN = (1 + xGX) * a2
      xC2 = Math.sqrt(xNN**2 + b2**2)
      xH2 = CieLab2Hue(xNN, b2)
      xDL = l2 - l1
      xDC = xC2 - xC1
      if (xC1 * xC2) == 0
        xDH = 0
      else
        xNN = (xH2 - xH1).round(12)
        if xNN.abs <= 180
          xDH = xH2 - xH1
        else
          if xNN > 180
            xDH = xH2 - xH1 - 360
          else
            xDH = xH2 - xH1 + 360
          end
        end
      end
      xDH = 2 * Math.sqrt(xC1 * xC2) * Math.sin(deg_to_rad(xDH / 2.0))
      xLX = (l1 + l2) / 2.0
      xCY = (xC1 + xC2) / 2.0
      if xC1 * xC2 == 0
        xHX = xH1 + xH2
      else
        xNN = (xH1 - xH2).round(12).abs
        if xNN > 180
          if xH2 + xH1 < 360
            xHX = xH1 + xH2 + 360
          else
            xHX = xH1 + xH2 - 360
          end
        else
          xHX = xH1 + xH2
        end
        xHX /= 2.0
      end
      xTX = 1 - 0.17 * Math.cos(deg_to_rad(xHX - 30)) + 0.24 *
                       Math.cos(deg_to_rad(2 * xHX)) + 0.32 *
                       Math.cos(deg_to_rad(3 * xHX + 6)) - 0.20 *
                       Math.cos(deg_to_rad(4 * xHX - 63 ))
      xPH = 30 * Math.exp(-((xHX - 275) / 25.0) * ((xHX  - 275) / 25.0))
      xRC = 2 * Math.sqrt(xCY**7 / (xCY**7 + 25**7))
      xSL = 1 + ((0.015 * ((xLX - 50) * (xLX - 50))) /
            Math.sqrt(20 + ((xLX - 50) * (xLX - 50))))
      xSC = 1 + 0.045 * xCY
      xSH = 1 + 0.015 * xCY * xTX
      xRT = -Math.sin(deg_to_rad(2 * xPH)) * xRC
      xDL = xDL / (kl * xSL)
      xDC = xDC / (kc * xSC)
      xDH = xDH / (kh * xSH)
      de = Math.sqrt(xDL**2 + xDC**2 + xDH**2 + xRT * xDC * xDH)
    end
  end

  class Palette
    attr_reader :type

    def initialize(type)
      @type = case type
              when "auto"
                if ENV.has_key? "TERM" and ENV["TERM"] == "xterm-256color"
                  "extended"
                else
                  "ansi"
                end
              when "extended"
                "extended"
              else
                raise "Unknown palette type '#{type}'."
              end

      # ANSI colours (the first 16) are configurable by users in most
      # terminals. The palette bellow contains the definitions for xterm,
      # which can be quite different from the colours of your terminal.
      #
      # For best results, please, take the time to configure the proper
      # set of colours via the tco configuration file.
      @palette = [
        Colour.new([0, 0, 0]),
        Colour.new([205, 0, 0]),
        Colour.new([0, 205, 0]),
        Colour.new([205, 205, 0]),
        Colour.new([0, 0, 238]),
        Colour.new([205, 0, 205]),
        Colour.new([0, 205, 205]),
        Colour.new([229, 229, 229]),
        Colour.new([127, 127, 127]),
        Colour.new([255, 0, 0]),
        Colour.new([0, 255, 0]),
        Colour.new([255, 255, 0]),
        Colour.new([92, 92, 255]),
        Colour.new([255, 0, 255]),
        Colour.new([0, 255, 255]),
        Colour.new([255, 255, 255]),

        Colour.new([0, 0, 0]),
        Colour.new([0, 0, 95]),
        Colour.new([0, 0, 135]),
        Colour.new([0, 0, 175]),
        Colour.new([0, 0, 215]),
        Colour.new([0, 0, 255]),
        Colour.new([0, 95, 0]),
        Colour.new([0, 95, 95]),
        Colour.new([0, 95, 135]),
        Colour.new([0, 95, 175]),
        Colour.new([0, 95, 215]),
        Colour.new([0, 95, 255]),
        Colour.new([0, 135, 0]),
        Colour.new([0, 135, 95]),
        Colour.new([0, 135, 135]),
        Colour.new([0, 135, 175]),
        Colour.new([0, 135, 215]),
        Colour.new([0, 135, 255]),
        Colour.new([0, 175, 0]),
        Colour.new([0, 175, 95]),
        Colour.new([0, 175, 135]),
        Colour.new([0, 175, 175]),
        Colour.new([0, 175, 215]),
        Colour.new([0, 175, 255]),
        Colour.new([0, 215, 0]),
        Colour.new([0, 215, 95]),
        Colour.new([0, 215, 135]),
        Colour.new([0, 215, 175]),
        Colour.new([0, 215, 215]),
        Colour.new([0, 215, 255]),
        Colour.new([0, 255, 0]),
        Colour.new([0, 255, 95]),
        Colour.new([0, 255, 135]),
        Colour.new([0, 255, 175]),
        Colour.new([0, 255, 215]),
        Colour.new([0, 255, 255]),
        Colour.new([95, 0, 0]),
        Colour.new([95, 0, 95]),
        Colour.new([95, 0, 135]),
        Colour.new([95, 0, 175]),
        Colour.new([95, 0, 215]),
        Colour.new([95, 0, 255]),
        Colour.new([95, 95, 0]),
        Colour.new([95, 95, 95]),
        Colour.new([95, 95, 135]),
        Colour.new([95, 95, 175]),
        Colour.new([95, 95, 215]),
        Colour.new([95, 95, 255]),
        Colour.new([95, 135, 0]),
        Colour.new([95, 135, 95]),
        Colour.new([95, 135, 135]),
        Colour.new([95, 135, 175]),
        Colour.new([95, 135, 215]),
        Colour.new([95, 135, 255]),
        Colour.new([95, 175, 0]),
        Colour.new([95, 175, 95]),
        Colour.new([95, 175, 135]),
        Colour.new([95, 175, 175]),
        Colour.new([95, 175, 215]),
        Colour.new([95, 175, 255]),
        Colour.new([95, 215, 0]),
        Colour.new([95, 215, 95]),
        Colour.new([95, 215, 135]),
        Colour.new([95, 215, 175]),
        Colour.new([95, 215, 215]),
        Colour.new([95, 215, 255]),
        Colour.new([95, 255, 0]),
        Colour.new([95, 255, 95]),
        Colour.new([95, 255, 135]),
        Colour.new([95, 255, 175]),
        Colour.new([95, 255, 215]),
        Colour.new([95, 255, 255]),
        Colour.new([135, 0, 0]),
        Colour.new([135, 0, 95]),
        Colour.new([135, 0, 135]),
        Colour.new([135, 0, 175]),
        Colour.new([135, 0, 215]),
        Colour.new([135, 0, 255]),
        Colour.new([135, 95, 0]),
        Colour.new([135, 95, 95]),
        Colour.new([135, 95, 135]),
        Colour.new([135, 95, 175]),
        Colour.new([135, 95, 215]),
        Colour.new([135, 95, 255]),
        Colour.new([135, 135, 0]),
        Colour.new([135, 135, 95]),
        Colour.new([135, 135, 135]),
        Colour.new([135, 135, 175]),
        Colour.new([135, 135, 215]),
        Colour.new([135, 135, 255]),
        Colour.new([135, 175, 0]),
        Colour.new([135, 175, 95]),
        Colour.new([135, 175, 135]),
        Colour.new([135, 175, 175]),
        Colour.new([135, 175, 215]),
        Colour.new([135, 175, 255]),
        Colour.new([135, 215, 0]),
        Colour.new([135, 215, 95]),
        Colour.new([135, 215, 135]),
        Colour.new([135, 215, 175]),
        Colour.new([135, 215, 215]),
        Colour.new([135, 215, 255]),
        Colour.new([135, 255, 0]),
        Colour.new([135, 255, 95]),
        Colour.new([135, 255, 135]),
        Colour.new([135, 255, 175]),
        Colour.new([135, 255, 215]),
        Colour.new([135, 255, 255]),
        Colour.new([175, 0, 0]),
        Colour.new([175, 0, 95]),
        Colour.new([175, 0, 135]),
        Colour.new([175, 0, 175]),
        Colour.new([175, 0, 215]),
        Colour.new([175, 0, 255]),
        Colour.new([175, 95, 0]),
        Colour.new([175, 95, 95]),
        Colour.new([175, 95, 135]),
        Colour.new([175, 95, 175]),
        Colour.new([175, 95, 215]),
        Colour.new([175, 95, 255]),
        Colour.new([175, 135, 0]),
        Colour.new([175, 135, 95]),
        Colour.new([175, 135, 135]),
        Colour.new([175, 135, 175]),
        Colour.new([175, 135, 215]),
        Colour.new([175, 135, 255]),
        Colour.new([175, 175, 0]),
        Colour.new([175, 175, 95]),
        Colour.new([175, 175, 135]),
        Colour.new([175, 175, 175]),
        Colour.new([175, 175, 215]),
        Colour.new([175, 175, 255]),
        Colour.new([175, 215, 0]),
        Colour.new([175, 215, 95]),
        Colour.new([175, 215, 135]),
        Colour.new([175, 215, 175]),
        Colour.new([175, 215, 215]),
        Colour.new([175, 215, 255]),
        Colour.new([175, 255, 0]),
        Colour.new([175, 255, 95]),
        Colour.new([175, 255, 135]),
        Colour.new([175, 255, 175]),
        Colour.new([175, 255, 215]),
        Colour.new([175, 255, 255]),
        Colour.new([215, 0, 0]),
        Colour.new([215, 0, 95]),
        Colour.new([215, 0, 135]),
        Colour.new([215, 0, 175]),
        Colour.new([215, 0, 215]),
        Colour.new([215, 0, 255]),
        Colour.new([215, 95, 0]),
        Colour.new([215, 95, 95]),
        Colour.new([215, 95, 135]),
        Colour.new([215, 95, 175]),
        Colour.new([215, 95, 215]),
        Colour.new([215, 95, 255]),
        Colour.new([215, 135, 0]),
        Colour.new([215, 135, 95]),
        Colour.new([215, 135, 135]),
        Colour.new([215, 135, 175]),
        Colour.new([215, 135, 215]),
        Colour.new([215, 135, 255]),
        Colour.new([215, 175, 0]),
        Colour.new([215, 175, 95]),
        Colour.new([215, 175, 135]),
        Colour.new([215, 175, 175]),
        Colour.new([215, 175, 215]),
        Colour.new([215, 175, 255]),
        Colour.new([215, 215, 0]),
        Colour.new([215, 215, 95]),
        Colour.new([215, 215, 135]),
        Colour.new([215, 215, 175]),
        Colour.new([215, 215, 215]),
        Colour.new([215, 215, 255]),
        Colour.new([215, 255, 0]),
        Colour.new([215, 255, 95]),
        Colour.new([215, 255, 135]),
        Colour.new([215, 255, 175]),
        Colour.new([215, 255, 215]),
        Colour.new([215, 255, 255]),
        Colour.new([255, 0, 0]),
        Colour.new([255, 0, 95]),
        Colour.new([255, 0, 135]),
        Colour.new([255, 0, 175]),
        Colour.new([255, 0, 215]),
        Colour.new([255, 0, 255]),
        Colour.new([255, 95, 0]),
        Colour.new([255, 95, 95]),
        Colour.new([255, 95, 135]),
        Colour.new([255, 95, 175]),
        Colour.new([255, 95, 215]),
        Colour.new([255, 95, 255]),
        Colour.new([255, 135, 0]),
        Colour.new([255, 135, 95]),
        Colour.new([255, 135, 135]),
        Colour.new([255, 135, 175]),
        Colour.new([255, 135, 215]),
        Colour.new([255, 135, 255]),
        Colour.new([255, 175, 0]),
        Colour.new([255, 175, 95]),
        Colour.new([255, 175, 135]),
        Colour.new([255, 175, 175]),
        Colour.new([255, 175, 215]),
        Colour.new([255, 175, 255]),
        Colour.new([255, 215, 0]),
        Colour.new([255, 215, 95]),
        Colour.new([255, 215, 135]),
        Colour.new([255, 215, 175]),
        Colour.new([255, 215, 215]),
        Colour.new([255, 215, 255]),
        Colour.new([255, 255, 0]),
        Colour.new([255, 255, 95]),
        Colour.new([255, 255, 135]),
        Colour.new([255, 255, 175]),
        Colour.new([255, 255, 215]),
        Colour.new([255, 255, 255]),
        Colour.new([8, 8, 8]),
        Colour.new([18, 18, 18]),
        Colour.new([28, 28, 28]),
        Colour.new([38, 38, 38]),
        Colour.new([48, 48, 48]),
        Colour.new([58, 58, 58]),
        Colour.new([68, 68, 68]),
        Colour.new([78, 78, 78]),
        Colour.new([88, 88, 88]),
        Colour.new([98, 98, 98]),
        Colour.new([108, 108, 108]),
        Colour.new([118, 118, 118]),
        Colour.new([128, 128, 128]),
        Colour.new([138, 138, 138]),
        Colour.new([148, 148, 148]),
        Colour.new([158, 158, 158]),
        Colour.new([168, 168, 168]),
        Colour.new([178, 178, 178]),
        Colour.new([188, 188, 188]),
        Colour.new([198, 198, 198]),
        Colour.new([208, 208, 208]),
        Colour.new([218, 218, 218]),
        Colour.new([228, 228, 228]),
        Colour.new([238, 238, 238])
      ]
    end

    def set_colour_value(id, rgb_colour)
      raise "Id '#{id}' out of range." unless id.between?(0, @palette.length-1)
      @palette[id] = Colour.new(rgb_colour)
    end

    def get_colour_value(id)
      raise "Id '#{id}' out of range." unless id.between?(0, @palette.length-1)
      @palette[id].rgb
    end

    # Returns an index of the closest colour in the palette
    def match_colour(colour)
      unless colour.is_a? Colour
        msg = "Unsupported argument type '#{colour.class}', must be 'Colour'."
        raise ArgumentError.new msg
      end

      colours = case @type
                when "extended" then @palette
                when "ansi" then @palette[0,16]
                end

      # TODO: This is too simple ... optimize (add caching?)
      distances = colours.map { |c| c - colour }
      distances.each_with_index.min[1]
    end
  end
end
