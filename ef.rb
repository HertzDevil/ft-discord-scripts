#!/usr/bin/ruby

DESC = 'Returns a default equivalent sequence for an effect command.
Usage: ./ef.rb <effect>
Supported effects: 4 (absolute sequence), 7, A, T.'

VIB_DEPTH = [
	 1.0,  1.5,  2.5,  4.0,  5.0,  7.0, 10.0,  12.0,
  14.0, 17.0, 22.0, 30.0, 44.0, 64.0, 96.0, 128.0,
]
VIB_TABLE = VIB_DEPTH.map do |x|
  (0..15).map do |p|
    (Math.sin(Math::PI / 32.0 * p) * x).floor
  end
end

if ARGV.empty?
  puts DESC; exit
end

cmd, xval, yval = nil
begin
  _, cmd, xval, yval = *ARGV[0].match(/^(.)([0-9A-Fa-f])([0-9A-Fa-f])$/)
  xval = Integer(xval, 16)
  yval = Integer(yval, 16)
rescue
  STDERR.puts 'Error while parsing arguments.'
  exit 1
end

case cmd
when '4'
  if xval == 0 || yval == 0
    print '0'; return
  end
  puts '| ' + ((1..(64 / (xval.gcd 64))).map do |x|
    case phase = xval * x % 64
    when 0..15
      -VIB_TABLE[yval][phase]
    when 16..31
      -VIB_TABLE[yval][31 - phase]
    when 32..47
      VIB_TABLE[yval][phase - 32]
    when 48..63
      VIB_TABLE[yval][63 - phase]
    end
  end.join ' ')
when '7'
  if xval == 0 || yval == 0
    print '0'; return
  end
  puts '| ' + ((1..(64 / (xval.gcd 64))).map do |x|
    case phase = (xval * x % 64) >> 1
    when 0..15
      [1, 15 - VIB_TABLE[yval][phase]].max
    when 16..31
      [1, 15 - VIB_TABLE[yval][31 - phase]].max
    end
  end.join ' ')
when 'A'
  vol = xval > yval ? 0 : 0x78
  while true
    newvol = vol - yval
    newvol = 0 if newvol < 0
    newvol += xval
    newvol = 0x7F if newvol > 0x7F
    print (newvol > 0 && newvol < 8 ? 1 : newvol >> 3), ' '
    break if vol == newvol
    vol = newvol
  end
when 'T'
  puts('0 ' * (xval & 7) + (yval * (xval >= 8 ? -1 : 1)).to_s)
else
  STDERR.puts 'Unrecognized effect command.'
end
