#!/usr/bin/ruby

DESC = 'Tuplet calculator, ported from Lua.
Usage: ./tuplet.rb <rows> <notes> [<option>...]
Options:
  -Tx: Set tempo to x (default 150)
  -Sx[,x...]: Set speed to x, use multiple values for groove (default 6)
  -Rx: Set refresh rate to x (default 60)
  -v: Show tick count and error in output'

def croak(msg)
  STDERR.puts msg
  exit 1
end

def calc_tuplets(rows, notes, opt = {})
  count = [0]
  final = []

  tick = lambda do |row|
    opt[:rate] * opt[:speed][row % opt[:speed].length] * 2.5 / opt[:tempo]
  end

  rows.times do |x|
    count << (count.last + tick.call(x))
  end

  notes.times do |n|
    offset = count.last * n / notes
    place = (count.index {|c| offset - c + 0.5 < 0} || count.length) - 1
    gxx = offset - count[place]
    final << {row: place, Gxx: gxx, error: gxx.round - gxx,
      length: (offset + count.last / notes).round - offset.round}
  end

  final.each_cons(2) do |left, right|
    next if left[:row] != right[:row]
    return nil if left[:Gxx] >= 0.5
    left[:row] -= 1
    left[:Gxx] += tick.call(left[:row])
  end

  final if final.all? {|r| r[:Gxx].round <= 0xFF} &&
    final.each_cons(2).all? {|left, right| left[:row] != right[:row]}
end

def gxx_string(rows, notes, opt)
  pattern = calc_tuplets(rows, notes, opt)
  return 'No tuplet sequences can be found.' if not pattern

  roffs = pattern.first[:row]
  pattern.each {|r| r[:row] -= roffs}

  speed = nil
  (rows - roffs).times.map do |x|
    fxx = opt[:speed][(x + roffs) % opt[:speed].length]
    fxxstr = fxx != speed ? 'F%02X' % fxx : '...'
    speed = fxx
    if note = pattern.find {|r| r[:row] == x}
      notestr, delay = 'C-3 00 .', note[:Gxx].round
      comment = !opt[:showcomments] ? '' :
        '    # length = %2d; error = %+.2f' % [note[:length], note[:error]]
    else
      notestr, delay, comment = '... .. .', 0, ''
    end
    'ROW %02X : ... .. . %s : %s %s%s' % [
      x - roffs, fxxstr, notestr, delay > 0 ? 'G%02X' % delay : '...', comment]
  end.join "\n"
end

if ARGV.length < 2
  puts DESC
  exit
end
rows, notes = ARGV.shift(2).map(&:to_i)
opt = {tempo: 150, speed: [6], rate: 60}
ARGV.each do |x|
  case x
  when /^\-T(.*)$/
    opt[:tempo] = $1.to_i
  when /^\-S(.*)$/
    opt[:speed] = $1.split(',').map(&:to_i)
  when /^\-R(.*)$/
    opt[:rate] = $1.to_f
  when /^\-v$/
    opt[:showcomments] = true
  else
    croak 'Error while parsing arguments.'
  end
end
croak 'Error while parsing arguments.' if rows <= 0 || notes <= 0 ||
  opt[:tempo] <= 0 || opt[:rate] <= 0 ||
  opt[:speed].empty? || opt[:speed].any? {|x| x <= 0}
puts gxx_string(rows, notes, opt)
