# encoding: UTF-8

# windows fix
$command = Gem.win_platform? ? 'magick convert' : 'convert'

input, output = ARGV[0..1].push '', ''
output = File.basename(input,'.*')+'.png' if output == ''

unless File.file? input
	puts 'Given file does not exists'
	abort
end

# [255,255,255,255] => #FFFFFFFF
def rgba_to_hex r, g, b, a
	hex = '#'
	['r', 'g', 'b', 'a']. each do |color|
		c = binding.local_variable_get(color).to_s(16).upcase
		c = [].fill('0', 0, 2-c.length).join('') + c
		hex += c
	end
	hex
end

# collects and draw points
class DrawCollector
	def initialize output, max = 512
		@max = max
		@points = []
		# files
		@input = ''
		@output = output
		# progress
		@all = 1
		@now = 0
	end

	def read! input
		@input = input
		File.open(@input, 'r:UTF-8') do |f|
			@all += 1 while f.getc
		end
		# square root rounded up is the best resolution for image
		img_size = Math.sqrt(@all).ceil
		%x(#{$command} -size #{img_size}x#{img_size} xc:"rgba(0,0,0,0)" png32:"#{@output}")

		x, y = 0, 0
		# read file
		File.open(@input, 'r:UTF-8') do |f|
			while char = f.getc
				# character into 4 bytes
				r, g, b, a = 4.times.map do |byte|
					char.bytes[byte].nil? ? 0 : char.bytes[byte]
				end

				# push pixel
				self.add! x, y, r, g, b, a

				# move pixel
				x += 1
				if x == img_size
					 y += 1
					 x = 0
				end
			end
		end

		# add End-of-text character (U+0003)
		self.add! x, y, 3, 0, 0, 0

		# release if something wait for draw
		self.release!
	end

	def add! x, y, r, g, b ,a
		@now += 1

		hex = rgba_to_hex r, g, b, 255 - a
		@points.push "-draw \"fill #{hex} color #{x},#{y} point\""
		self.release! if @points.count > @max

		self.print_progress!
	end

	def print_progress!
		progress = ((@now.to_f / @all.to_f) * 100).ceil
		print "\r\r"
		print "progress: #{progress}% | #{@now}/#{@all}px\s"
	end

	def release!
		draw_all = @points.join " "
		@points = []
		if draw_all.length > 0
			%x(#{$command} "#{@output}" #{draw_all} "#{@output}")
		end
	end
end

collector = DrawCollector.new output
collector.read! input

# 🦄 here's a little unicorn for testing purposes :3
