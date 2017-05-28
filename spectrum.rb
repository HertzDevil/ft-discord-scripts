#!/usr/bin/ruby

DESC = 'Computes the spectrum of a waveform. No scaling is done.
Options, can appear anywhere:
- `db`: Output values in decibels'

#def ft(a, b, f, k)
#  return k * (b - a) if f == 0
#  w = 2.0 * Math::PI * f
#  k / w * (Math.sin(w * b) - Math.sin(w * a) +
#    1i * (Math.cos(w * b) - Math.cos(w * a)))
#end

def ft_step(a, s, f, k)
  return k / s.to_f if f == 0
  pi_f = Math::PI * f
  Math.sin(pi_f / s) * k / pi_f *
    Math::E ** (-(2.0 * a + 1.0 / s) * pi_f * 1i)
end

def spectrum(f, *t)
  (0..f).map do |f|
    t.map.with_index do |x, k|
      ft_step(k.to_f / t.size, t.size, f, x)
    end.reduce(0, &:+)
  end
end

samples = []
db = false

if ARGV.empty?
  puts DESC
  exit
end
ARGV.each do |x|
  case x
  when 'db'
    db = true
  else
    begin
      samples << Float(x)
    rescue
      STDERR.puts 'Error while parsing arguments.'
      exit 1
    end
  end
end
if samples.size < 2
  STDERR.puts 'At least two samples are required.'
  exit 1
end

s = spectrum(25, *samples).map &:magnitude
dc = s.shift
s.map! {|x| 20.0 * Math.log(x < 1e-12 ? 0 : x, 10)} if db
print s.map.with_index {|x, k| '% 8.4f%s' % [x, k % 5 == 4 ? "\n" : '  ']}.join
print '%sDC: %.4f' % [s.size % 5 == 0 ? '' : "\n", dc]
