# encoding: UTF-8

# windows fix
$command = Gem.win_platform? ? 'magick convert' : 'convert'

input, output = ARGV[0..1].push '', ''
output = File.basename(input,'.*')+'.txt' if output == ''

unless File.file? input
	puts 'Given file does not exists'
	abort
end

def hex_to_rgba hex
	# color size for 64-bit is 4 bytes but for 32-bit is 2 bytes
	color_size = hex.length > 9 ? 4 : 2
	hex.to_s.gsub(/^#/, '').scan(/.{1,#{color_size}}/).map do |byte|
		byte.nil? ? 0 : byte.to_i(16)
	end
end

class Array
	# removes items from end of array until dont finds other one
	def right_reject val
		(0..self.count-1).reverse_each do |i|
			break unless self[i] == val
			self.delete_at(i)
		end
		self
	end
end

# open result
output_f = File.open(output, 'w:UTF-8')

# make output sync with spawned process
STDOUT.sync = true

# call for reading pixels
IO.popen("#{$command} \"#{input}\" txt:") do |out|
	out.each do |line|
		# get hex color
		color = line[/#([0-9A-F]{6,16})/i].to_s

		# ignore lines w/o colors e.g imagemagick header
		next if color.length < 2

		# color bytes
		r, g, b, a = hex_to_rgba color

		# find for End-of-text character (U+0003)
		break if [r, g, b, a] == [3, 0, 0, 255]

		# remove empties from right
		bytes = [r, g, b, 255-a].right_reject 0

		# ignore empty character
		next if bytes.nil? or bytes.count < 1

		# write character
		output_f.write bytes.pack('C*').force_encoding('utf-8')
	end
end

puts 'Done!'
output_f.close
