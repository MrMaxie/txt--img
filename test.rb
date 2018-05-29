# encoding: UTF-8
STDOUT.sync = true

args = ARGV.map &:downcase

ONLY_READ = args.include? '--read'
BIG_TEST  = args.include? '--big'

big = BIG_TEST ? 'big_' : ''

%x{ ruby txt2img.rb test/#{big}sample.txt test/#{big}result.png } unless ONLY_READ
%x{ ruby img2txt.rb test/#{big}result.png test/#{big}result.txt }

# compare files
f1 = IO.readlines("test/#{big}sample.txt").map &:chomp
f2 = IO.readlines("test/#{big}result.txt").map &:chomp
diff = f1 - f2

puts "diff.count = #{diff.count}"

File.open "test/#{big}diff.txt", 'w' do |f|
	f.write diff.join "\n"
end
