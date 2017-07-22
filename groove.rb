#!/usr/bin/ruby

DESC = 'BPM-to-groove converter.
Usage: ./groove.rb <bpm> [<option>...]
Options:
- `bpm`: BPM value (overrides previosu value)
- `beat`: first highlight value (default 4)
- `hz`: refresh rate (default 60)
- `rows`: groove size, result groove must fit evenly
- `max`: maximum groove size (default 16)
Examples:
- `groove 120 bpm` => `8 7`
- `groove 120 8 beat` => `4 4 4 3`
- `groove 150 45 hz` => `5 4`
- `groove 165 4 rows` => `6 5`
- `groove 170 8 max` => `6 5 5 6 5 5 5`'

def get_args(t)
  args = {beat: 4, hz: 60, max: 16}
  need_num = true
  last = nil

  t.each do |x|
    if need_num
      begin
        last = Float(x)
      rescue
        return
      end
      need_num = false
    else
      case x
      when 'bpm', 'beat', 'hz', 'rows', 'max'
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
    (!args[:rows] || args[:rows] % 1 == 0) &&
    args.all? {|k, v| v.is_a?(Numeric) && v > 0}
end

def get_groove(params)
  ticks = Rational(60 * params[:hz], params[:bpm] * params[:beat])
  return [1] if ticks < 1
  return [255] if ticks > 255

  best = (1..params[:max]).map do |k|
    next if params[:rows] && params[:rows] % k != 0
    cycle = (ticks * k).round
    [k, cycle, cycle / k.to_f]
  end.compact.min do |a, b|
    [(ticks - a[2]).abs, a[0]] <=> [(ticks - b[2]).abs, b[0]]
  end

  (0...best[0]).map do |t|
    (best[1] * (t + 1) - 1) / best[0] - (best[1] * t - 1) / best[0]
  end
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
bpm = params[:hz] * 60 * groove.size / params[:beat] / groove.reduce(0, &:+)
error = bpm / params[:bpm] - 1

puts groove.join ' '
puts 'Actual BPM: %.2f (%+4.1f%%)' % [bpm, error * 100]
