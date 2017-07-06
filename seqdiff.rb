#!/usr/bin/ruby

DESC = 'Absolute-to-relative sequence converter.
Usage: ./seqdiff.rb <value>...
Value types:
- `x`: sequence entry, both "$" and "0x" denote hex values
- `x:y`: repeat `x` for `y` times
- `x:y:z`: line from `x` (inclusive) to `z` (exclusive) for `y` entries
- "|", "L": loop point, at most one is allowed
- "/", "R": release point (FamiTracker behaviour), at most one is allowed
- "$$": interpret remaining values as hexadecimal
Sequences containing release points may not have the same behaviour if notes are released before the sustain part finishes.
The release point must not come after the loop point if both are present.'

def croak(msg)
  STDERR.puts msg
  exit 1
end

def convert(arg)
  loop = nil
  release = nil
  sequence = []

  always_hex = false
  get_int = lambda do |str|
    return Integer(str[1...str.size], 16) if str[0] == '$'
    return -Integer(str[2...str.size], 16) if str[0..1] == '-$'
    always_hex ? Integer(str, 16) : Integer(str)
  end

  begin
    arg.each do |x|
      case x
      when '$$'
        always_hex = true
      when '|', 'L', 'l'
        croak 'Multiple loop points are not allowed.' if loop
        loop = sequence.size
      when '/', 'R', 'r'
        croak 'Multiple release points are not allowed.' if release
        release = sequence.size
      when /^(.*?):(.*?):(.*)$/
        lo, count, hi = get_int.call($1), get_int.call($2), get_int.call($3)
        (0...count).each do |i|
          offset = i * (hi - lo).abs / count
          sequence << (hi >= lo ? lo + offset : lo - offset)
        end
      when /^(.*?):(.*)$/
        val, count = get_int.call($1), get_int.call($2)
        count.times {sequence << val}
      else
        sequence << get_int.call(x)
      end
    end
  rescue ArgumentError
    croak 'Error while parsing arguments.'
  end

  croak 'Sequence cannot be empty.' if sequence.empty?
  croak 'Last entry cannot be a loop point.' if loop == sequence.size
  croak 'Last entry cannot be a release point.' if release == sequence.size

  if release
    if loop
      croak 'Sequence must not loop before the release point.' if loop < release
      loop += 1
    end
    sequence.insert(release, sequence[release])
    release += 1
  end

  if loop
    sequence << sequence[loop]
    loop += 1
  end

  relative = sequence.each_cons(2).map {|x, y| y - x}.unshift sequence[0]
  relative.each_with_index do |v, i|
    print '/ ' if i == release
    print '| ' if i == loop
    print v, ' '
  end
end

if ARGV.empty?
  puts DESC
  exit
end
convert(ARGV)
