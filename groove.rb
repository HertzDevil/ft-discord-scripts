#!/usr/bin/ruby

DESC = 'BPM-to-groove converter for power-of-two sizes.
Usage: ./groove.rb <bpm> [<option>...]
Options:
- `beat`: first highlight value (default 4)
- `hz`: refresh rate (default 60)
- `max`: maximum groove size (default 16)
- `ntsc`: equivalent to `60.0988 hz`
- `pal`: equivalent to `50.007 hz`
- `usec`: refresh interval in microseconds
Examples:
- `./groove.rb 120` => `8 7`
- `./groove.rb 120 8 beat` => `4 4 4 3`
- `./groove.rb 150 45 hz` => `5 4`
- `./groove.rb 170 8 max` => `6 5 5 5`'

def get_args(t)
  args = {beat: 4, bpm: t.shift.to_f, hz: 60, max: 16}
  need_num = true
  last = nil

  t.each do |x|
    if need_num
      case x
      when 'ntsc'
        args[:hz] = 60.0988
      when 'pal'
        args[:hz] = 50.007
      else
        begin
          last = x.to_f
        rescue
          return
        end
        need_num = false
      end
    else
      case x
      when 'usec'
        args[:hz] = 1000000.0 / last
        need_num = true
      when 'bpm', 'beat', 'hz', 'max'
        args[x.to_sym] = last
        need_num = true
      else
        args[:bpm] = last
        last = x.to_f
        #return
      end
    end
  end

  args[:bpm] = last if !need_num

  args if args[:bpm] && args[:beat] % 1 == 0 &&
    args.all? {|k, v| v.is_a?(Numeric) && v > 0}
end

def make_groove(ticks, gsize)
  return [ticks] if gsize == 1
  make_groove(ticks - ticks / 2, gsize / 2) + make_groove(ticks / 2, gsize / 2)
end

def get_groove(params)
  gsize = 2 ** Math.log2(params[:max]).to_i
  total = (60 * params[:hz] / (params[:bpm] * params[:beat]) * gsize).round
  while total.even? && gsize.even?
    total, gsize = total / 2, gsize / 2
  end

  g = make_groove(total, gsize)
  return [1] if g.any? {|x| x < 1}
  return [255] if g.any? {|x| x > 255}
  g
end

if ARGV.empty?
  puts DESC
  exit
end
params = get_args ARGV
if !params then
  STDERR.puts 'Error while parsing arguments.'
  exit 1
end

groove = get_groove(params)
bpm = params[:hz] * 60.0 * groove.size / params[:beat] / groove.reduce(0, &:+)
error = bpm / params[:bpm] - 1

puts groove.join ' '
puts 'Actual BPM: %.2f (%+.3g%%)' % [bpm, error * 100]
