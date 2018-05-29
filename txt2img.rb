# encoding: UTF-8

require 'chunky_png'
require 'optparse'

module Txt2img
	def convert!
	end
	class << self

		def hex_to_dec x
			x = x.gsub(/#/,'').scan(/.{2}/).map do |hex| hex.to_i(10) end
			x.push 255 if x.count == 3
		end
	end
end

def hex_to_dec x
	x = x.gsub(/#/,'').scan(/.{2}/).map do |hex| hex.to_i(10) end
	x.push 255 if x.count == 3
end

private :hex_to_dec

def txt2img(input, output=nil, options={})
	# lambda functions

	#
	@options = {
		chars_limit: false,
		width: false,
		height: false,
		simulate: false,
		quiet: true,
		color_offset: '#00000000',
		background: '#000000FF'
	}.merge(options)

	unless File.file? input
	 	raise'given input file does not exists'
	end

	output = output.nil? ? input + '.png' : output
	unless @options[:quiet]
		puts "Input: #{input}"
		puts "Output: #{output}"
	end

	chars = 0
	limit = @options[:chars_limit]
	File.open(input, 'r:UTF-8') do |f|
		while f.getc
			chars += 1
			if limit.is_a? Integer and chars >= limit
				break
			end
		end
	end
	chars += 2

	# calculate size
	if @options[:width] === false and @options[:height] === false
		width, height = [Math.sqrt(chars).ceil] * 2
	elsif @options[:width] === false
		height = @options[:height]
		width  = (chars.to_f/height.to_f).ceil
	elsif @options[:height] === false
		width  = @options[:width]
		height = (chars.to_f/width.to_f).ceil
	else
		width, height = @options[:width], @options[:height]
		if width * height < chars and !@options[:quiet]
			puts "Specified size is too small, #{chars - (width * height)} characters will not fit"
			answer = nil
			until %w[n y].include? answer
				print 'Continue? [Y/n] '
				answer = gets.rstrip.downcase
				if answer.empty?
					answer = 'y'
				end
			end
			if answer == 'n'
				puts 'Aborted'
				abort
			end
		end
	end
	unless @options[:quiet]
		puts "Image size: #{width}×#{height}"
	end

	image = ChunkyPNG::Image.new width, height
end

# Command-line access
if __FILE__ == $PROGRAM_NAME then
	options = {
		quiet: false
	}
	OptionParser.new do |o|
		o.banner  = "Usage: #{$PROGRAM_NAME} <input> [<output>] [options...]\n\n"

		o.on('-l=LIMIT', '--chars-limit=LIMIT', 'Determines count of processed characters', Integer) do |x|
			options[:chars_limit] = x if x > 0
		end

		valid_hex = -> (x) {
			unless (/^#?[a-f0-9]{6}([a-f0-9]{2})?$/i) =~ x
				raise OptionParser::InvalidArgument.new 'given color don\'t looks like RGB(A) hex color'
			end
		}

		o.on('-w=WIDTH', '--width=WIDTH', 'Determine width of image', Integer) do |x|
			options[:width] = x if x > 0
		end

		o.on('-h=HEIGHT', '--height=HEIGHT', 'Determine height of image', Integer) do |x|
			options[:height] = x if x > 0
		end

		o.on('-s', '--simulate', 'No file is created') do |x|
			options[:simulate] = x
		end

		o.on('-q', '--quiet', 'Nothing will be printed') do |x|
			options[:quiet] = x
		end

		o.on('-c', '--color-offset=HEX-COLOR', 'Determines the color being a NULL character; Accepts RGB(A) hex') do |x|
			valid_hex.call x
			options[:color_offset] = x
		end

		o.on('-b', '--background=HEX-COLOR', 'Determines color which will fill unused pixels; Accepts RGB(A) hex') do |x|
			valid_hex.call x

			p x.gsub(/#/,'').scan(/.{2}/).map do |hex| hex.to_i(10) end
			# puts ChunkyPNG::Color.r(ChunkyPNG::Color.from_hex(x))

			options[:background] = x
		end

		o.on('--help', 'Show this message') do
			puts o
			exit
		end
	end.parse!

	input  = ARGV.pop || ''
	output = ARGV.pop
	txt2img input, output, options
end

=begin
# windows fix
$command = Gem.win_platform? ? 'magick convert' : 'convert'

# arguments parsing
args = {
	chars: 0,
	w: 0,
	h: 0,
	simulate: false,
	offset: 0
}
flag = nil # mem about last found flag
ARGV.select! do |arg|
	if arg.start_with? '--'
		flag = arg[2..-1].downcase
		args[flag] = args.key?(flag) and [true, false].include? args[flag]

		false
	elsif not args.key? flag
		flag = nil

		false
	elsif not flag.nil?
		if args[flag].is_a? Integer
			args[flag] = arg.to_i
		end
		if [true, false].include? args[flag]
			args[flag] = ['true','on','y','t','yes'].include? arg.downcase
		end

		false
	else
		true
	end
end

puts ARGV
abort

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
		self.release! if @points.count > @max and @max > 0

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

collector = DrawCollector.new output, 256
collector.read! input

# 🦄 here's a little unicorn for testing purposes :3

30 + 40 + 20 + 30 + 40 + 40 + 40 + 30 + 30 + 40
=end
