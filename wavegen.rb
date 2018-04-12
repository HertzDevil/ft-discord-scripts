#!/usr/bin/ruby

require 'wavefile'

OUTNAME = 'sampled.fti'

DESC = 'Samples a WAV file as an N163 instrument.
Usage: ./wavegen.rb [<option>...] <infile>
Options:
- `-Lx`: Number of oscillations in loop region (default 1)
- `-Bx`: Wave loop point in samples (default 0)
- `-Wx`: N163 wave size (default 32)
- `-Cx`: N163 wave count (default 16)
- `-Rx`: Refresh rate (Hz) (default 60.0)
- `-Tx`: Semitone transpose (default +0.0)'

def croak(str)
  STDERR.puts str
  exit 1
end

def get_args(t)
  args = {fname: t.pop,
    loopstart: 0, loopcount: 1,
    wavesize: 32, wavecount: 16, refresh: 60.0, transpose: 0.0,
  }
  croak 'File does not exist.' if !File.exist?(args[:fname])
  begin
    t.each do |x|
      case x
      when /^\-L(\d+)$/
        args[:loopcount] = Integer($1)
      when /^\-B(\d+)$/
        args[:loopstart] = Integer($1)
      when /^\-W(\d+)$/
        args[:wavesize] = Integer($1)
      when /^\-C(\d+)$/
        args[:wavecount] = Integer($1)
      when /^\-R(\d+\.?\d*)$/
        args[:refresh] = $1.to_f
      when /^\-T(\-?\d+\.?\d*)$/
        args[:transpose] = $1.to_f
      end
    end
    croak 'Invalid arguments.' if args[:loopcount] <= 0 || args[:loopstart] < 0 ||
      args[:wavesize] < 4 || args[:wavesize] > 240 || args[:wavesize] % 4 != 0 ||
      args[:wavecount] < 1 || args[:wavecount] > 64 ||
      args[:refresh] <= 0.0
  rescue ArgumentError
    croak 'Error while parsing arguments.'
  end
  args
end

def get_sample(samps, i)
  s = samps.size
  i_near = i.round
  z = 0
  (-FILTER_WIDTH..FILTER_WIDTH).each do |t|
    z += samps[(i_near + z) % s] * L2.(i + t - i_near)
  end
  z
end

class SampleReader
  attr_reader :loopfix, :wavesize, :wavecount, :seqlen

  def initialize(args = {})
    @loopstart = args[:loopstart] || 0
    @wavesize  = args[:wavesize]  || 32
    @wavecount = args[:wavecount] || 16
    @refresh   = args[:refresh]   || 60.0

    reader = WaveFile::Reader.new(args[:fname],
      WaveFile::Format.new(:mono, :float, 48000))
    @samples = []
    reader.each_buffer do |buffer|
      @samples += buffer.samples
    end

    loopcount = args[:loopcount] || 1
    x = (@samples.size - @loopstart) / loopcount
    @loopfix = (@samples.size / x).floor
    extrasamples = (@samples.size - @loopfix * x).round
    @loopstart -= extrasamples
    @samples = @samples.drop(extrasamples)
    @lo, @hi = @samples.minmax
    @seqlen = (@samples.size / (reader.native_format.sample_rate / @refresh) /
      2.0 ** ((args[:transpose] || 0.0) / 12.0)).round

    @window = -> (x) do
      px = Math::PI * x
      x == 0 ? 1 : (x.abs >= FILTER_WIDTH ? 0 :
        (FILTER_WIDTH * Math.sin(px) * Math.sin(px / FILTER_WIDTH) / px ** 2))
    end
  end

  def total_samples
    @samples.size
  end
  
  def get_wave(wave_no)
    clip_samples(@wavesize.times.map do |i|
      s = (wave_no + (i + 0.5) / @wavesize) * @samples.size / @loopfix
      get_sample(s)
    end)
  end

  def loop_point
    l = (@loopstart.to_f / @samples.size * @refresh).round
    (l < 0 ? 0 : l >= @seqlen ? @seqlen - 1 : l).to_i
  end

private
  FILTER_WIDTH = 2

  def get_sample(idx)
    s = @samples.size
    i_near = idx.round
    z = 0
    (-FILTER_WIDTH..FILTER_WIDTH).each do |t|
      z += @samples[(i_near + z) % s] * @window.(idx + t - i_near)
    end
    z
  end

  def clip_samples(s)
    return [8] * @wavesize if @lo == @hi
    s.map do |x|
      x = ((x - @lo) / (@hi - @lo) * 16).floor
      x < 0 ? 0 : x > 15 ? 15 : x
    end
  end
end

def make_samples(args)
  reader = SampleReader.new(args)

  out = "FTI2.4\x05" + [args[:fname].size].pack('<I') + args[:fname] +
    "\x05\x00\x00\x00\x00\x01" +
    [reader.seqlen, reader.loop_point, -1, 0].pack('<I<I<I<I')
  reader.seqlen.times do |x|
    out += [(x.to_f / reader.seqlen * reader.wavecount).floor].pack 'C'
  end
  out += [reader.wavesize, 0, reader.wavecount].pack('<I<I<I')
  reader.wavecount.times do |x|
    idx = ((x * reader.loopfix + 0.1) / reader.wavecount).round
    samps = reader.get_wave(idx)
    out += samps.pack('U*')
  end
  out
end

croak DESC if ARGV.empty?
params = get_args ARGV
croak 'Error while parsing arguments.' if !params

File.open(OUTNAME, 'wb') do |f|
  f.write make_samples(params)
end
