# encoding: UTF-8
STDOUT.sync = true
ONLY_READ = false

%x{ ruby txt2img.rb test/sample.txt test/result.png } unless ONLY_READ
%x{ ruby img2txt.rb test/result.png test/result.txt }

# compare files
f1 = IO.readlines('test/sample.txt').map &:chomp
f2 = IO.readlines('test/result.txt').map &:chomp
diff = f1 - f2

puts "diff.count = #{diff.count}"

File.open 'test/diff.txt', 'w' do |f|
	f.write diff.join "\n"
end
